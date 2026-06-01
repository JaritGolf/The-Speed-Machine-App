//
//  TrainingSessionView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//
//  UI designed for 5-foot viewing distance — all text uses large, bold fonts.
//  Minimum font size: ~24pt on iPhone. Use fs() helper for all sizes so they
//  scale automatically on iPad (1.4×).
//
//  iPad orientation:  GeometryReader at the TrainingSessionView level injects
//  `isLandscapeOrientation` into the environment.  All child views consume it
//  via @Environment(\.isLandscapeOrientation) instead of verticalSizeClass,
//  which does NOT distinguish portrait/landscape on iPad.
//

import SwiftUI
import UIKit
import Combine

// MARK: - Main Session Router

struct TrainingSessionView: View {
    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    @State private var showEndSessionAlert = false
    @State private var lastRecordedSpeed: Float = 0.0

    var session: SessionProgress? { trainingViewModel.currentSession }
    var block: TrainingBlock? { trainingViewModel.selectedBlock }
    var track: TrainingTrack? { trainingViewModel.selectedTrack }

    var body: some View {
        // GeometryReader injects reliable isLandscapeOrientation for both iPhone
        // (verticalSizeClass works) and iPad (size classes stay .regular always).
        GeometryReader { geo in
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()

                if let dayStats = trainingViewModel.trackCompleteStats {
                    // Day complete — show summary screen with tap-to-dismiss Done button
                    DayCompleteView(stats: dayStats)
                } else if let session = session, let block = block, let track = track {
                    if let nextBlock = trainingViewModel.nextBlockForTransition {
                        // Inter-block transition screen
                        BlockTransitionView(track: track, nextBlock: nextBlock)
                    } else if let gateResult = trainingViewModel.gateTestResult {
                        GateTestResultView(result: gateResult, session: session, block: block, track: track)
                    } else if let skillCheck = trainingViewModel.pendingSkillCheck {
                        // Phase 3: block failed threshold — show repeat / continue anyway
                        SkillCheckResultView(
                            evaluation: skillCheck,
                            session: session,
                            block: block,
                            track: track
                        )
                    } else if session.isComplete && !trainingViewModel.blockCompletionPending && !trainingViewModel.blockJustCompleted {
                        SessionCompleteView(session: session, block: block, track: track)
                    } else {
                        // Route based on block session type (Day 7 special challenges)
                        switch session.blockSessionType {
                        case .eliminationLadder:
                            LadderSessionView(session: session, block: block, track: track)
                        case .makeInRow:
                            MakeInRowSessionView(session: session, block: block, track: track)
                        default:
                            // Route based on block type for standard blocks
                            switch block.type {
                            case .exploration:
                                ExplorationSessionView(session: session, block: block, track: track, isTransitioning: false)
                            case .pressure:
                                PressureSessionView(session: session, block: block, track: track, isTransitioning: false)
                            case .gateTest:
                                GateTestSessionView(session: session, block: block, track: track)
                            default:
                                ActiveSessionView(session: session, block: block, track: track, isTransitioning: false)
                            }
                        }
                    }
                }

                // "✓ BLOCK COMPLETE" banner — floats over any live session view for 2 seconds
                // after the final putt lands. Clears automatically when completeBlock() fires.
                if trainingViewModel.blockJustCompleted {
                    VStack {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: fs(28), weight: .bold))
                                .foregroundColor(.white)
                            Text("BLOCK COMPLETE")
                                .font(.system(size: fs(28), weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 18)
                        .background(AppColors.accentGreen)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)

                        Spacer()
                    }
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: trainingViewModel.blockJustCompleted)
                    .ignoresSafeArea(edges: .top)
                }
            }
            .environment(\.isLandscapeOrientation, geo.size.width > geo.size.height)
            .onChange(of: bluetoothService.currentSpeed) { _, newSpeed in
                if newSpeed > 0 && newSpeed != lastRecordedSpeed {
                    recordPutt(newSpeed)
                    lastRecordedSpeed = newSpeed
                }
            }
        }
        .onAppear {
            // Allow landscape while the live session is on screen
            AppDelegate.allowLandscape = true
        }
        .onDisappear {
            // Lock back to portrait when returning to menus
            AppDelegate.allowLandscape = false
            // Snap back to portrait immediately
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        }
    }

    func recordPutt(_ speed: Float) {
        trainingViewModel.recordPutt(speed)
        if let result = session?.puttRecords.last {
            if result.isInZone {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
        }
    }
}

// MARK: - Standard Active Session View

struct ActiveSessionView: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let track: TrainingTrack
    let isTransitioning: Bool

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    private var passThreshold: Int {
        guard let t = MasteryService.shared.blockThreshold(for: block, track: track.number) else { return 0 }
        return Int(ceil(t * Float(session.totalPutts)))
    }

    var body: some View {
        SportLiveContainer(
            session: session,
            block: block,
            track: track,
            stripConfig: .standard(
                totalPutts: session.totalPutts,
                puttsTaken: session.currentPutt,
                inZone: session.inZonePutts,
                passThreshold: passThreshold
            ),
            headerIcon: .rec,
            bluetoothService: bluetoothService,
            adaptiveContext: trainingViewModel.adaptiveBlockContext
        )
    }
}

// MARK: - Exploration Session View

struct ExplorationSessionView: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let track: TrainingTrack
    let isTransitioning: Bool

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    var body: some View {
        SportLiveContainer(
            session: session,
            block: block,
            track: track,
            stripConfig: .exploration(puttsTaken: session.currentPutt),
            headerIcon: .rec,
            bluetoothService: bluetoothService,
            adaptiveContext: trainingViewModel.adaptiveBlockContext
        )
    }
}

// MARK: - Pressure Session View

struct PressureSessionView: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let track: TrainingTrack
    let isTransitioning: Bool

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var showEndSessionAlert = false
    @Environment(\.isLandscapeOrientation) var isLandscape

    var lastPutt: PuttResult? { session.puttRecords.last }
    var isConsecutiveChallenge: Bool { block.challengeType == "consecutive" }

    var body: some View {
        VStack(spacing: 0) {
            PressureHeaderCompact(track: track, block: block, bluetoothService: bluetoothService)
            BlockThresholdStrip(session: session, block: block, track: track)

            if isLandscape {
                GeometryReader { geo in
                    HStack(spacing: 8) {
                        // Left: target
                        targetCard
                            .frame(width: geo.size.width * 0.45)

                        // Center: challenge status
                        challengeStatusView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white).cornerRadius(24)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.border, lineWidth: 1))

                        // Right: last putt + end
                        VStack(spacing: 8) {
                            if let lastPutt = lastPutt {
                                LastPuttCardLarge(lastPutt: lastPutt)
                            }
                            EndSessionButtonCompact(showEndSessionAlert: $showEndSessionAlert)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, max(6, geo.safeAreaInsets.bottom))
                    .padding(.leading, max(12, geo.safeAreaInsets.leading + 4))
                    .padding(.trailing, max(12, geo.safeAreaInsets.trailing + 4))
                }
                .ignoresSafeArea(edges: .horizontal)
            } else {
                VStack(spacing: 8) {
                    // Challenge status — prominent
                    challengeStatusView
                        .padding(.vertical, 16).padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .background(Color.white).cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.border, lineWidth: 1))

                    // Target — fills remaining space
                    targetCard

                    if let lastPutt = lastPutt {
                        LastPuttCardLarge(lastPutt: lastPutt)
                    }

                    EndSessionButtonCompact(showEndSessionAlert: $showEndSessionAlert)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .padding(.top, 4)
            }
        }
        .alert("End Session?", isPresented: $showEndSessionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { trainingViewModel.endSession() }
        } message: {
            Text("Are you sure you want to end this pressure challenge? Your progress will be saved.")
        }
    }

    @ViewBuilder
    var targetCard: some View {
        VStack(spacing: 0) {
            Spacer()
            if isTransitioning {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: isLandscape ? fs(80) : fs(100)))
                    .foregroundColor(AppColors.accentGreen)
                Text("DONE")
                    .font(.system(size: isLandscape ? fs(60) : fs(72), weight: .black, design: .rounded))
                    .foregroundColor(AppColors.accentGreen)
            } else {
                Text("TARGET")
                    .font(.system(size: isLandscape ? fs(24) : fs(28), weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textMuted).tracking(3)
                Text("\(session.currentTargetSpeed)")
                    .font(.system(size: isLandscape ? fs(180) : fs(220), weight: .black, design: .rounded))
                    .foregroundColor(AppColors.primaryBlack)
                    .minimumScaleFactor(0.3).lineLimit(1)
                Text("MPH")
                    .font(.system(size: isLandscape ? fs(28) : fs(32), weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textMuted)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white).cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(isTransitioning ? AppColors.accentGreen : AppColors.border, lineWidth: isTransitioning ? 3 : 1))
    }

    @ViewBuilder
    var challengeStatusView: some View {
        if isConsecutiveChallenge {
            VStack(spacing: 12) {
                Text("HIT \(block.consecutiveRequired ?? 5) IN A ROW")
                    .font(.system(size: fs(28), weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.primaryBlack)
                HStack(spacing: 10) {
                    ForEach(0..<(block.consecutiveRequired ?? 5), id: \.self) { index in
                        Circle()
                            .fill(index < session.consecutiveSuccesses ? AppColors.accentGreen : AppColors.border)
                            .frame(width: 44, height: 44)
                            .overlay(
                                index < session.consecutiveSuccesses ?
                                Image(systemName: "checkmark").font(.title3).fontWeight(.bold).foregroundColor(.white) : nil
                            )
                    }
                }
                Text("\(session.consecutiveSuccesses) / \(block.consecutiveRequired ?? 5)")
                    .font(.system(size: fs(36), weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.accentGreen)
            }
        } else {
            VStack(spacing: 12) {
                Text("LIVES")
                    .font(.system(size: fs(28), weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textMuted).tracking(2)
                HStack(spacing: 14) {
                    ForEach(0..<(block.lives ?? 3), id: \.self) { index in
                        Image(systemName: index < session.livesRemaining ? "heart.fill" : "heart")
                            .font(.system(size: fs(40)))
                            .foregroundColor(index < session.livesRemaining ? AppColors.error : AppColors.border)
                    }
                }
            }
        }
    }
}

// MARK: - Gate Test Session View

struct GateTestSessionView: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let track: TrainingTrack

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    private var passThreshold: Int {
        guard let req = block.passRequirements else { return 0 }
        return req.minOverallInZone ?? req.zoneAccuracy?.minimum ?? 6
    }

    var body: some View {
        SportLiveContainer(
            session: session,
            block: block,
            track: track,
            stripConfig: .gateTest(
                totalPutts: session.totalPutts,
                puttsTaken: session.currentPutt,
                inZone: session.inZonePutts,
                passThreshold: passThreshold
            ),
            headerIcon: .flag,
            bluetoothService: bluetoothService
        )
    }
}

// MARK: - Gate Test Result View

struct GateTestResultView: View {
    let result: GateTestResult
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let track: TrainingTrack
    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @Environment(\.isLandscapeOrientation) var isLandscape

    var body: some View {
        if isLandscape {
            GeometryReader { geo in
                HStack(spacing: 16) {
                    // Left: pass/fail icon + title
                    VStack(spacing: 12) {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(result.passed ? AppColors.accentLight : Color.red.opacity(0.1))
                                .frame(width: 120, height: 120)
                            Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: fs(70)))
                                .foregroundColor(result.passed ? AppColors.accentGreen : AppColors.error)
                        }
                        Text(result.passed ? "PASSED" : "FAILED")
                            .font(.system(size: fs(48), weight: .black, design: .rounded))
                            .foregroundColor(result.passed ? AppColors.accentGreen : AppColors.error)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Right: stats + button
                    VStack(spacing: 16) {
                        Spacer()
                        HStack {
                            Text("IN ZONE")
                                .font(.system(size: fs(28), weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.textMuted)
                            Spacer()
                            Text("\(result.zoneAccuracyAchieved)/\(result.zoneAccuracyRequired)")
                                .font(.system(size: fs(40), weight: .black, design: .rounded))
                                .foregroundColor(result.zoneAccuracyAchieved >= result.zoneAccuracyRequired ? AppColors.accentGreen : AppColors.error)
                        }
                        .padding(20).background(Color.white).cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.border, lineWidth: 1))

                        if !result.passed {
                            GateFailureReasonsView(result: result, compact: true)
                        }

                        Button {
                            trainingViewModel.endSession()
                        } label: {
                            Text(result.passed ? "Continue" : "Try Again Later")
                                .font(.system(size: fs(28), weight: .bold, design: .rounded))
                                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(AppColors.accentGreen).cornerRadius(18)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 12)
                .padding(.bottom, max(12, geo.safeAreaInsets.bottom))
                .padding(.leading, max(20, geo.safeAreaInsets.leading + 8))
                .padding(.trailing, max(20, geo.safeAreaInsets.trailing + 8))
            }
            .ignoresSafeArea(edges: .horizontal)
        } else {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 16)

                    ZStack {
                        Circle()
                            .fill(result.passed ? AppColors.accentLight : Color.red.opacity(0.1))
                            .frame(width: 160, height: 160)
                        Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: fs(90)))
                            .foregroundColor(result.passed ? AppColors.accentGreen : AppColors.error)
                    }

                    Text(result.passed ? "PASSED" : "FAILED")
                        .font(.system(size: fs(56), weight: .black, design: .rounded))
                        .foregroundColor(result.passed ? AppColors.accentGreen : AppColors.error)

                    HStack {
                        Text("IN ZONE")
                            .font(.system(size: fs(28), weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textMuted)
                        Spacer()
                        Text("\(result.zoneAccuracyAchieved)/\(result.zoneAccuracyRequired)")
                            .font(.system(size: fs(44), weight: .black, design: .rounded))
                            .foregroundColor(result.zoneAccuracyAchieved >= result.zoneAccuracyRequired ? AppColors.accentGreen : AppColors.error)
                    }
                    .padding(24).background(Color.white).cornerRadius(24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.border, lineWidth: 1))

                    if !result.passed {
                        GateFailureReasonsView(result: result, compact: false)
                    }

                    Button {
                        trainingViewModel.endSession()
                    } label: {
                        Text(result.passed ? "Continue" : "Try Again Later")
                            .font(.system(size: fs(28), weight: .bold, design: .rounded))
                            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 20)
                            .background(AppColors.accentGreen).cornerRadius(18)
                    }
                    Spacer(minLength: 16)
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Block Transition Screen

// MARK: - Gate Failure Reasons View

/// Shown inside GateTestResultView when the gate test is failed.
/// Displays each failed criterion with its displayName and remediationMessage,
/// plus average deviation and worst miss stats when available.
private struct GateFailureReasonsView: View {
    let result: GateTestResult
    let compact: Bool   // true = landscape compact layout

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {

            // Deviation stats row (if available)
            if let avgDev = result.avgAbsDeviation, let maxDev = result.maxDeviation {
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.2f", avgDev))
                            .font(.system(size: fs(compact ? 28 : 36), weight: .black, design: .rounded))
                            .foregroundColor(AppColors.primaryBlack)
                        Text("AVG DEV (MPH)")
                            .font(.system(size: fs(compact ? 14 : 16), weight: .heavy, design: .rounded))
                            .foregroundColor(AppColors.textMuted)
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(AppColors.border)
                        .frame(width: 1)
                        .padding(.vertical, 8)

                    VStack(spacing: 4) {
                        Text(String(format: "%.2f", maxDev))
                            .font(.system(size: fs(compact ? 28 : 36), weight: .black, design: .rounded))
                            .foregroundColor(AppColors.primaryBlack)
                        Text("WORST MISS (MPH)")
                            .font(.system(size: fs(compact ? 14 : 16), weight: .heavy, design: .rounded))
                            .foregroundColor(AppColors.textMuted)
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
            }

            // Per-criterion failure list
            if !result.failureReasons.isEmpty {
                VStack(alignment: .leading, spacing: compact ? 6 : 10) {
                    Text("WHAT TO WORK ON")
                        .font(.system(size: fs(compact ? 14 : 16), weight: .heavy, design: .rounded))
                        .foregroundColor(AppColors.textMuted)
                        .tracking(1.5)
                        .padding(.bottom, 2)

                    ForEach(result.failureReasons, id: \.rawValue) { reason in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: fs(compact ? 18 : 20)))
                                .foregroundColor(AppColors.accentAmber)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(reason.displayName)
                                    .font(.system(size: fs(compact ? 16 : 20), weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.primaryBlack)
                                Text(reason.remediationMessage)
                                    .font(.system(size: fs(compact ? 14 : 18), weight: .regular, design: .rounded))
                                    .foregroundColor(AppColors.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(compact ? 10 : 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.border, lineWidth: 1))
                    }
                }
            }
        }
    }
}

// MARK: - Block Transition View

struct BlockTransitionView: View {
    let track: TrainingTrack
    let nextBlock: TrainingBlock

    @State private var countdown: Int = 3
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var nextBlockNumber: Int {
        (track.blocks.firstIndex(where: { $0.id == nextBlock.id }) ?? 0) + 1
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Green checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: fs(60), weight: .bold))
                    .foregroundColor(AppColors.accentGreen)
                    .padding(.bottom, 20)

                // BLOCK COMPLETE
                Text("BLOCK COMPLETE")
                    .font(.inter(fs(32)))
                    .foregroundColor(.white)
                    .tracking(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 44)

                // UP NEXT label
                Text("UP NEXT")
                    .font(.inter(fs(11), weight: .bold))
                    .kerning(2.2)
                    .foregroundColor(AppColors.accentGreen)

                Spacer().frame(height: 14)

                // Next block name
                Text(nextBlock.name.uppercased())
                    .font(.inter(fs(48)))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 10)

                // Block metadata
                Text("TRACK \(track.number)  ·  BLOCK \(nextBlockNumber)  ·  \(nextBlock.putts ?? 0) PUTTS")
                    .font(.inter(fs(13), weight: .bold))
                    .foregroundColor(.white.opacity(0.50))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 40)

                // Countdown circle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 5)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: CGFloat(countdown) / 3.0)
                        .stroke(AppColors.accentGreen, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.9), value: countdown)
                    Text("\(countdown)")
                        .font(.inter(fs(36)))
                        .foregroundColor(.white)
                }

                Spacer().frame(height: 10)

                Text("STARTING IN")
                    .font(.inter(fs(11), weight: .bold))
                    .kerning(2.0)
                    .foregroundColor(.white.opacity(0.50))

                Spacer()
            }
        }
        .onReceive(timer) { _ in
            if countdown > 0 { countdown -= 1 }
        }
    }
}

// MARK: - Session Complete Screen

struct SessionCompleteView: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let track: TrainingTrack
    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @Environment(\.isLandscapeOrientation) var isLandscape

    var body: some View {
        if isLandscape {
            GeometryReader { geo in
                HStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Spacer()
                        ZStack {
                            Circle().fill(AppColors.accentLight).frame(width: 100, height: 100)
                            Image(systemName: "checkmark.circle.fill").font(.system(size: fs(60))).foregroundColor(AppColors.accentGreen)
                        }
                        Text("COMPLETE")
                            .font(.system(size: fs(44), weight: .black, design: .rounded))
                            .foregroundColor(AppColors.primaryBlack)
                        Text("Track \(track.number)")
                            .font(.system(size: fs(28), weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textMuted)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(spacing: 12) {
                        VStack(spacing: 14) {
                            SessionStatRowLarge(label: "Accuracy", value: "\(Int(session.zoneAccuracy * 100))%")
                            Divider()
                            SessionStatRowLarge(label: "In Zone", value: "\(session.inZonePutts)/\(session.currentPutt)")
                        }
                        .padding(20).background(Color.white).cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.border, lineWidth: 1))

                        Button {
                            trainingViewModel.endSession()
                        } label: {
                            Text("Continue")
                                .font(.system(size: fs(28), weight: .bold, design: .rounded))
                                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(AppColors.accentGreen).cornerRadius(16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 12)
                .padding(.bottom, max(12, geo.safeAreaInsets.bottom))
                .padding(.leading, max(20, geo.safeAreaInsets.leading + 8))
                .padding(.trailing, max(20, geo.safeAreaInsets.trailing + 8))
            }
            .ignoresSafeArea(edges: .horizontal)
        } else {
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle().fill(AppColors.accentLight).frame(width: 160, height: 160)
                    Image(systemName: "checkmark.circle.fill").font(.system(size: fs(90))).foregroundColor(AppColors.accentGreen)
                }
                VStack(spacing: 8) {
                    Text("COMPLETE")
                        .font(.system(size: fs(52), weight: .black, design: .rounded))
                        .foregroundColor(AppColors.primaryBlack)
                    Text("Track \(track.number)")
                        .font(.system(size: fs(32), weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textMuted)
                }
                VStack(spacing: 20) {
                    SessionStatRowLarge(label: "Accuracy", value: "\(Int(session.zoneAccuracy * 100))%")
                    Divider()
                    SessionStatRowLarge(label: "In Zone", value: "\(session.inZonePutts)/\(session.currentPutt)")
                }
                .padding(24).background(Color.white).cornerRadius(24)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.border, lineWidth: 1))
                Spacer()
                Button {
                    trainingViewModel.endSession()
                } label: {
                    Text("Continue")
                        .font(.system(size: fs(28), weight: .bold, design: .rounded))
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 20)
                        .background(AppColors.accentGreen).cornerRadius(18)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Track Complete View

struct DayCompleteView: View {
    let stats: TrackCompleteStats
    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @Environment(\.isLandscapeOrientation) var isLandscape

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Green checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: fs(60)))
                    .foregroundColor(AppColors.accentGreen)
                    .padding(.bottom, 20)

                // TRACK COMPLETE
                Text("TRACK COMPLETE")
                    .font(.inter(fs(32)))
                    .foregroundColor(.white)
                    .tracking(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)

                Text(String(format: "Track %d · Great work!", stats.trackNumber))
                    .font(.inter(fs(14), weight: .medium))
                    .foregroundColor(.white.opacity(0.60))
                    .padding(.top, 6)

                Spacer().frame(height: 36)

                // Hero number: track / 30
                HStack(alignment: .bottom, spacing: 8) {
                    Text(String(format: "%02d", stats.trackNumber))
                        .font(.inter(fs(80)))
                        .foregroundColor(.white)
                        .tracking(-2)
                    Text("/ \(TrainingConstants.totalTracks)")
                        .font(.inter(fs(22), weight: .bold))
                        .foregroundColor(.white.opacity(0.50))
                        .padding(.bottom, 10)
                }

                Text("TRACKS COMPLETE")
                    .font(.inter(fs(11), weight: .bold))
                    .kerning(2.2)
                    .foregroundColor(.white.opacity(0.50))

                Spacer().frame(height: 36)

                // Stats row
                HStack(spacing: 0) {
                    trackStatCell(value: "\(stats.totalPutts)", label: "PUTTS")
                    Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1, height: 36)
                    trackStatCell(value: "\(stats.accuracyPercent)%", label: "ACCURACY")
                    Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1, height: 36)
                    trackStatCell(value: practiceTimeString, label: "TIME")
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA
                Button {
                    trainingViewModel.endSession()
                    trainingViewModel.shouldNavigateHome = true
                } label: {
                    Text("Back to Tracks →")
                        .font(.inter(fs(17), weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppColors.accentGreen)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }

    private func trackStatCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.inter(fs(24)))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.inter(fs(10), weight: .bold))
                .kerning(1.5)
                .foregroundColor(.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity)
    }

    var practiceTimeString: String {
        if stats.practiceMinutes > 0 {
            return "\(stats.practiceMinutes)m"
        } else {
            return "\(stats.practiceSecondsRemainder)s"
        }
    }
}

// MARK: - Reusable Session Components

/// Compact header — BLE status dot + day/block name. Scales up on iPad.
struct SessionHeaderCompact: View {
    let track: TrainingTrack
    let block: TrainingBlock
    let bluetoothService: BluetoothService
    var adaptiveContext: String? = nil

    var blockNumber: Int {
        (track.blocks.firstIndex(where: { $0.id == block.id }) ?? 0) + 1
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.error)
                    .frame(width: 14, height: 14)
                Text("Track \(track.number): Block \(blockNumber): \(block.name)")
                    .font(.system(size: fs(28), weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.primaryBlack)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, adaptiveContext != nil ? 8 : 12)

            if let ctx = adaptiveContext {
                HStack(spacing: 5) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: fs(14), weight: .semibold))
                        .foregroundColor(AppColors.accentGreen)
                    Text(ctx)
                        .font(.system(size: fs(15), weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.accentGreen)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .background(Color.white.ignoresSafeArea(edges: .top))
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .bottom)
    }
}

struct PressureHeaderCompact: View {
    let track: TrainingTrack
    let block: TrainingBlock
    let bluetoothService: BluetoothService

    var blockNumber: Int {
        (track.blocks.firstIndex(where: { $0.id == block.id }) ?? 0) + 1
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: fs(28)))
                .foregroundColor(AppColors.error)
            Text("Track \(track.number): Block \(blockNumber): \(block.name)")
                .font(.system(size: fs(28), weight: .bold, design: .rounded))
                .foregroundColor(AppColors.error)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Spacer()
            Circle()
                .fill(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.error)
                .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.ignoresSafeArea(edges: .top))
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .bottom)
    }
}

struct GateTestHeaderCompact: View {
    let track: TrainingTrack
    let block: TrainingBlock
    let bluetoothService: BluetoothService

    var blockNumber: Int {
        (track.blocks.firstIndex(where: { $0.id == block.id }) ?? 0) + 1
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.checkered")
                .font(.system(size: fs(28)))
                .foregroundColor(AppColors.bleBlue)
            Text("Track \(track.number): Block \(blockNumber): \(block.name)")
                .font(.system(size: fs(28), weight: .bold, design: .rounded))
                .foregroundColor(AppColors.bleBlue)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Spacer()
            Circle()
                .fill(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.error)
                .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.ignoresSafeArea(edges: .top))
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .bottom)
    }
}

/// Last putt card — large readable speed + check/x. Scales on iPad.
struct LastPuttCardLarge: View {
    let lastPutt: PuttResult
    @Environment(\.isLandscapeOrientation) var isLandscape

    var body: some View {
        HStack(spacing: 10) {
            Text(lastPutt.actualSpeed.toSpeedString())
                .font(.system(size: isLandscape ? fs(64) : fs(80), weight: .bold, design: .rounded))
                .foregroundColor(lastPutt.isInZone ? AppColors.accentGreen : AppColors.error)
                .minimumScaleFactor(0.3).lineLimit(1)

            Image(systemName: lastPutt.isInZone ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: isLandscape ? fs(36) : fs(44)))
                .foregroundColor(lastPutt.isInZone ? AppColors.accentGreen : AppColors.error)
        }
        .padding(.vertical, isLandscape ? 8 : 14)
        .frame(maxWidth: .infinity, maxHeight: isLandscape ? .infinity : nil)
        .background(Color.white).cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(lastPutt.isInZone ? AppColors.accentGreen.opacity(0.3) : AppColors.error.opacity(0.3), lineWidth: 2)
        )
    }
}

/// Minimal progress bar — putt count + accuracy. Scales on iPad.
/// Still used by GateTestSessionView; ActiveSessionView/ExplorationSessionView
/// now show the equivalent info inline in the BlockThresholdStrip's second row.
struct ProgressBarMinimal: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("PUTT \(session.currentPutt)/\(session.totalPutts)")
                    .font(.system(size: fs(26), weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.primaryBlack)
                Spacer()
                Text("\(Int(session.zoneAccuracy * 100))%")
                    .font(.system(size: fs(36), weight: .black, design: .rounded))
                    .foregroundColor(AppColors.accentGreen)
            }
            ProgressBarView(current: session.currentPutt, total: session.totalPutts, color: AppColors.accentGreen)
                .frame(height: 16)
        }
        .padding(16)
        .background(Color.white).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
    }
}

/// End session button — large tap target. Scales on iPad.
struct EndSessionButtonCompact: View {
    @Binding var showEndSessionAlert: Bool

    var body: some View {
        Button {
            showEndSessionAlert = true
        } label: {
            Text("End Session")
                .font(.system(size: fs(26), weight: .bold, design: .rounded))
                .foregroundColor(AppColors.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white).cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.error.opacity(0.3), lineWidth: 1))
        }
    }
}

/// Stat row for completion screens. Scales on iPad.
struct SessionStatRowLarge: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: fs(28), weight: .medium, design: .rounded))
                .foregroundColor(AppColors.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: fs(36), weight: .black, design: .rounded))
                .foregroundColor(AppColors.primaryBlack)
        }
    }
}

// MARK: - BlockThresholdStrip

/// Persistent threshold strip shown directly under the block header on every live session screen.
/// Visible at all times during a block — not revealed only at block-end.
///
/// Sizing follows CLAUDE.md 5–6 foot viewing-distance rule:
///   primary count: 32–40pt bold
///   labels: 20–24pt heavy
///
/// Color states:
///   neutral  — below threshold, still mathematically achievable
///   green    — at or above threshold (block continues, user keeps putting)
///   amber    — mathematically impossible to pass (block still runs for rep volume)
struct BlockThresholdStrip: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let track: TrainingTrack
    // Observing the loader directly ensures this view re-renders whenever
    // a remote program update arrives, picking up the latest blockPassThreshold.
    @ObservedObject private var programLoader = TrainingProgramLoader.shared

    private var liveBlock: TrainingBlock {
        programLoader.program?.tracks
            .first(where: { $0.number == track.number })?
            .blocks.first(where: { $0.id == block.id }) ?? block
    }

    private var stripContent: ThresholdStripContent {
        ThresholdStripContent(session: session, block: liveBlock, track: track)
    }

    var body: some View {
        Group {
            switch stripContent.mode {
            case .standard(let inZone, let total, let threshold, let thresholdPct):
                StandardThresholdRow(inZone: inZone, total: total,
                                     threshold: threshold, thresholdPct: thresholdPct,
                                     session: session)
            case .gateTest(let inZone, let total, let minOverall, let minPerSpeed, let avgDev, let devCap):
                GateTestThresholdRow(inZone: inZone, total: total, minOverall: minOverall,
                                     minPerSpeed: minPerSpeed, avgDev: avgDev, devCap: devCap,
                                     session: session)
            case .pressure(let kind, let current, let target):
                PressureThresholdRow(kind: kind, current: current, target: target)
            case .combine:
                CombineThresholdRow()
            case .freePractice:
                FreePracticeRow()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.ignoresSafeArea(edges: .top))
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .bottom)
    }
}

// MARK: Strip Content Calculator

private enum StripMode {
    case standard(inZone: Int, total: Int, threshold: Int, thresholdPct: Int)
    case gateTest(inZone: Int, total: Int, minOverall: Int, minPerSpeed: Int, avgDev: Float, devCap: Float)
    case pressure(kind: String, current: Int, target: Int)
    case combine
    case freePractice
}

private struct ThresholdStripContent {
    let mode: StripMode

    init(session: SessionProgress, block: TrainingBlock, track: TrainingTrack) {
        // Combine
        if block.type == .combine {
            mode = .combine; return
        }
        // Skip gating
        if block.skipGating == true {
            mode = .freePractice; return
        }
        // Exploration with skipGating — first-day free exploration
        if block.type == .exploration && block.skipGating == true {
            mode = .freePractice; return
        }

        // Gate tests
        if block.type == .gateTest, let req = block.passRequirements {
            let avgDev = session.currentPutt > 0
                ? Float(session.puttRecords.reduce(0.0) { $0 + Double($1.difference) } / Double(session.currentPutt))
                : 0
            mode = .gateTest(
                inZone: session.inZonePutts,
                total: session.totalPutts,
                minOverall: req.minOverallInZone ?? req.zoneAccuracy?.minimum ?? 6,
                minPerSpeed: req.minPerSpeedInZone ?? 1,
                avgDev: avgDev,
                devCap: req.avgDeviationCapMph ?? 0.70
            )
            return
        }

        // Pressure (built-in progress)
        if block.type == .pressure {
            if block.challengeType == "consecutive" {
                mode = .pressure(kind: "streak",
                                 current: session.consecutiveSuccesses,
                                 target: block.consecutiveRequired ?? 5)
            } else if block.challengeType == "elimination" {
                mode = .pressure(kind: "lives",
                                 current: session.livesRemaining,
                                 target: block.lives ?? 3)
            } else {
                mode = .pressure(kind: "streak",
                                 current: session.consecutiveSuccesses,
                                 target: block.consecutiveRequired ?? 5)
            }
            return
        }

        // Ladder (elimination ladder)
        if session.blockSessionType == .eliminationLadder {
            mode = .pressure(kind: "rung",
                             current: session.currentRung + 1,
                             target: session.ladderSpeeds.count)
            return
        }

        // MakeInRow
        if session.blockSessionType == .makeInRow {
            mode = .pressure(kind: "streak",
                             current: session.consecutiveSuccesses,
                             target: block.consecutiveRequired ?? 5)
            return
        }

        // Standard / warmup / exploration / sequence / random / etc.
        let threshold = MasteryService.shared.blockThreshold(for: block, track: track.number)
        guard let threshold = threshold else {
            mode = .freePractice; return
        }
        let thresholdCount = Int(ceil(threshold * Float(session.totalPutts)))
        let thresholdPct = Int(threshold * 100)
        mode = .standard(inZone: session.inZonePutts,
                         total: session.totalPutts,
                         threshold: thresholdCount,
                         thresholdPct: thresholdPct)
    }
}

// MARK: Standard Threshold Row

private struct StandardThresholdRow: View {
    let inZone: Int
    let total: Int
    let threshold: Int   // count
    let thresholdPct: Int
    @ObservedObject var session: SessionProgress

    private var color: Color {
        let puttsLeft = total - session.currentPutt
        let needed = threshold - inZone
        if inZone >= threshold { return AppColors.accentGreen }
        if needed > puttsLeft  { return Color.orange }
        return AppColors.primaryBlack
    }

    private var showCheck: Bool { inZone >= threshold }

    private var accuracyPct: Int {
        guard session.currentPutt > 0 else { return 0 }
        return Int((Float(inZone) / Float(session.currentPutt)) * 100)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Row 1 — Headline: IN ZONE count + threshold reminder.
            // Sized large so the live success count is readable at 5–6 ft.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("IN ZONE")
                    .font(.system(size: fs(24), weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.textMuted)
                    .tracking(1.5)
                Text("\(inZone)")
                    .font(.system(size: fs(54), weight: .black, design: .rounded))
                    .foregroundColor(color)
                Text("/\(total)")
                    .font(.system(size: fs(30), weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textMuted)
                if showCheck {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: fs(28), weight: .bold))
                        .foregroundColor(AppColors.accentGreen)
                }
                Spacer()
                Text("PASS ≥ \(threshold) (\(thresholdPct)%)")
                    .font(.system(size: fs(22), weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.textMuted)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            // Row 2 — Live progress: putts remaining, attempt bar, accuracy %.
            // Replaces the old separate ProgressBarMinimal at the bottom of the screen.
            HStack(spacing: 12) {
                Text("PUTTS LEFT \(max(0, total - session.currentPutt))")
                    .font(.system(size: fs(24), weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.primaryBlack)
                    .layoutPriority(1)
                ProgressBarView(current: session.currentPutt, total: total, color: AppColors.accentGreen)
                    .frame(height: 14)
                Text("\(accuracyPct)%")
                    .font(.system(size: fs(32), weight: .black, design: .rounded))
                    .foregroundColor(AppColors.accentGreen)
                    .frame(minWidth: fs(70), alignment: .trailing)
            }
        }
    }
}

// MARK: Gate Test Threshold Row

private struct GateTestThresholdRow: View {
    let inZone: Int
    let total: Int
    let minOverall: Int
    let minPerSpeed: Int
    let avgDev: Float
    let devCap: Float
    @ObservedObject var session: SessionProgress

    private var zoneColor: Color {
        if inZone >= minOverall { return AppColors.accentGreen }
        let puttsLeft = total - session.currentPutt
        if minOverall - inZone > puttsLeft { return Color.orange }
        return AppColors.primaryBlack
    }
    private var devColor: Color {
        if avgDev <= devCap { return AppColors.accentGreen }
        return Color.orange
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Text("IN ZONE")
                    .font(.system(size: fs(20), weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.textMuted).tracking(1)
                Text("\(inZone)")
                    .font(.system(size: fs(36), weight: .bold, design: .rounded))
                    .foregroundColor(zoneColor)
                Text("/")
                    .font(.system(size: fs(20), weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textMuted)
                Text("\(total)")
                    .font(.system(size: fs(24), weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textMuted)
                if inZone >= minOverall {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: fs(20))).foregroundColor(AppColors.accentGreen)
                }
                Spacer()
                Text("PASS ≥ \(minOverall) overall, ≥ \(minPerSpeed)/spd")
                    .font(.system(size: fs(18), weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.textMuted)
                    .minimumScaleFactor(0.6).lineLimit(1)
            }
            HStack(spacing: 6) {
                Text("AVG DEV")
                    .font(.system(size: fs(18), weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.textMuted).tracking(1)
                Text(session.currentPutt > 0 ? String(format: "%.2f MPH", avgDev) : "--")
                    .font(.system(size: fs(22), weight: .bold, design: .rounded))
                    .foregroundColor(devColor)
                if session.currentPutt > 0 && avgDev <= devCap {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: fs(18))).foregroundColor(AppColors.accentGreen)
                }
                Spacer()
                Text("cap \(String(format: "%.2f", devCap)) MPH")
                    .font(.system(size: fs(18), weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.textMuted)
            }
        }
    }
}

// MARK: Pressure Threshold Row

private struct PressureThresholdRow: View {
    let kind: String   // "streak", "rung", "lives"
    let current: Int
    let target: Int

    var label: String {
        switch kind {
        case "streak": return "STREAK"
        case "rung":   return "RUNG"
        case "lives":  return "LIVES"
        default:       return kind.uppercased()
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: fs(20), weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.textMuted).tracking(1)
            Text("\(current)")
                .font(.system(size: fs(36), weight: .bold, design: .rounded))
                .foregroundColor(current >= target ? AppColors.accentGreen : AppColors.primaryBlack)
            Text("/")
                .font(.system(size: fs(20), weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textMuted)
            Text("\(target)")
                .font(.system(size: fs(24), weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textMuted)
            Spacer()
        }
    }
}

// MARK: Combine / Free Practice Rows

private struct CombineThresholdRow: View {
    var body: some View {
        HStack {
            Image(systemName: "target")
                .font(.system(size: fs(18), weight: .bold))
                .foregroundColor(AppColors.textMuted)
            Text("COMBINE — score not gated")
                .font(.system(size: fs(20), weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.textMuted)
            Spacer()
        }
    }
}

private struct FreePracticeRow: View {
    var body: some View {
        HStack {
            Image(systemName: "figure.golf")
                .font(.system(size: fs(18), weight: .bold))
                .foregroundColor(AppColors.textMuted.opacity(0.6))
            Text("FREE PRACTICE — no gate")
                .font(.system(size: fs(20), weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.textMuted.opacity(0.6))
            Spacer()
        }
    }
}

// MARK: - Backward-compatibility aliases

struct SessionHeader: View {
    let track: TrainingTrack; let block: TrainingBlock; let bluetoothService: BluetoothService
    var body: some View { SessionHeaderCompact(track: track, block: block, bluetoothService: bluetoothService) }
}
struct PressureHeader: View {
    let track: TrainingTrack; let block: TrainingBlock; let bluetoothService: BluetoothService
    var body: some View { PressureHeaderCompact(track: track, block: block, bluetoothService: bluetoothService) }
}
struct GateTestHeader: View {
    let track: TrainingTrack; let block: TrainingBlock; let bluetoothService: BluetoothService
    var body: some View { GateTestHeaderCompact(track: track, block: block, bluetoothService: bluetoothService) }
}
struct LastPuttCard: View {
    let lastPutt: PuttResult
    var body: some View { LastPuttCardLarge(lastPutt: lastPutt) }
}
struct SessionProgressCard: View {
    @ObservedObject var session: SessionProgress; let block: TrainingBlock
    var body: some View { ProgressBarMinimal(session: session, block: block) }
}
struct EndSessionButton: View {
    @Binding var showEndSessionAlert: Bool
    var body: some View { EndSessionButtonCompact(showEndSessionAlert: $showEndSessionAlert) }
}
struct LogoBadge: View {
    var body: some View {
        Image("SpeedMachineLogo").resizable().aspectRatio(contentMode: .fit)
            .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 10)).opacity(0.25)
    }
}
struct SessionStatRow: View {
    let label: String; let value: String
    var body: some View { SessionStatRowLarge(label: label, value: value) }
}
