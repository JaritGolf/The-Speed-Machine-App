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

// MARK: - Main Session Router

struct TrainingSessionView: View {
    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    @State private var showEndSessionAlert = false
    @State private var lastRecordedSpeed: Float = 0.0

    var session: SessionProgress? { trainingViewModel.currentSession }
    var block: TrainingBlock? { trainingViewModel.selectedBlock }
    var day: TrainingDay? { trainingViewModel.selectedDay }

    var body: some View {
        // GeometryReader injects reliable isLandscapeOrientation for both iPhone
        // (verticalSizeClass works) and iPad (size classes stay .regular always).
        GeometryReader { geo in
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()

                if let dayStats = trainingViewModel.dayCompleteStats {
                    // Day complete — show summary screen with tap-to-dismiss Done button
                    DayCompleteView(stats: dayStats)
                } else if let session = session, let block = block, let day = day {
                    if let nextBlock = trainingViewModel.nextBlockForTransition {
                        // Inter-block transition screen
                        BlockTransitionView(day: day, nextBlock: nextBlock)
                    } else if let gateResult = trainingViewModel.gateTestResult {
                        GateTestResultView(result: gateResult, session: session, block: block, day: day)
                    } else if session.isComplete && !trainingViewModel.blockCompletionPending && !trainingViewModel.blockJustCompleted {
                        SessionCompleteView(session: session, block: block, day: day)
                    } else {
                        // Route based on block session type (Day 7 special challenges)
                        switch session.blockSessionType {
                        case .eliminationLadder:
                            LadderSessionView(session: session, block: block, day: day)
                        case .makeInRow:
                            MakeInRowSessionView(session: session, block: block, day: day)
                        default:
                            // Route based on block type for standard blocks
                            switch block.type {
                            case .exploration:
                                ExplorationSessionView(session: session, block: block, day: day, isTransitioning: false)
                            case .pressure:
                                PressureSessionView(session: session, block: block, day: day, isTransitioning: false)
                            case .gateTest:
                                GateTestSessionView(session: session, block: block, day: day)
                            default:
                                ActiveSessionView(session: session, block: block, day: day, isTransitioning: false)
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
    let day: TrainingDay
    let isTransitioning: Bool

    var body: some View {
        SportLiveContainer(
            session: session,
            block: block,
            day: day,
            stripConfig: .standard(
                puttsLeft: max(0, session.totalPutts - session.currentPutt),
                puttsNeeded: max(0, (block.passRequirements?.zoneAccuracy.minimum ?? 0) - session.inZonePutts)
            ),
            headerIcon: .rec
        )
    }
}

// MARK: - Exploration Session View

struct ExplorationSessionView: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let day: TrainingDay
    let isTransitioning: Bool

    var body: some View {
        SportLiveContainer(
            session: session,
            block: block,
            day: day,
            stripConfig: .exploration(puttsTaken: session.currentPutt),
            headerIcon: .rec
        )
    }
}

// MARK: - Pressure Session View

struct PressureSessionView: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let day: TrainingDay
    let isTransitioning: Bool

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var showEndSessionAlert = false
    @Environment(\.isLandscapeOrientation) var isLandscape

    var lastPutt: PuttResult? { session.puttRecords.last }
    var isConsecutiveChallenge: Bool { block.challengeType == "consecutive" }

    var body: some View {
        VStack(spacing: 0) {
            PressureHeaderCompact(day: day, block: block, bluetoothService: bluetoothService)

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
    let day: TrainingDay

    var body: some View {
        let passMin = block.passRequirements?.zoneAccuracy.minimum ?? 0
        SportLiveContainer(
            session: session,
            block: block,
            day: day,
            stripConfig: .gateTest(
                puttsLeft: max(0, session.totalPutts - session.currentPutt),
                puttsNeeded: max(0, passMin - session.inZonePutts)
            ),
            headerIcon: .flag
        )
    }
}

// MARK: - Gate Test Result View

struct GateTestResultView: View {
    let result: GateTestResult
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let day: TrainingDay
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

                        if result.passed {
                            if let onPass = block.onPass {
                                Text(onPass)
                                    .font(.system(size: fs(24), weight: .medium))
                                    .foregroundColor(AppColors.textMuted)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            Text(block.onFail ?? "Practice more and try again.")
                                .font(.system(size: fs(24), weight: .medium))
                                .foregroundColor(AppColors.textMuted)
                                .multilineTextAlignment(.center)
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
            VStack(spacing: 24) {
                Spacer()

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

                if result.passed {
                    if let onPass = block.onPass {
                        Text(onPass)
                            .font(.system(size: fs(24), weight: .medium))
                            .foregroundColor(AppColors.textMuted)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                } else {
                    Text(block.onFail ?? "Practice more and try again.")
                        .font(.system(size: fs(24), weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }

                Spacer()

                Button {
                    trainingViewModel.endSession()
                } label: {
                    Text(result.passed ? "Continue" : "Try Again Later")
                        .font(.system(size: fs(28), weight: .bold, design: .rounded))
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 20)
                        .background(AppColors.accentGreen).cornerRadius(18)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Block Transition Screen

struct BlockTransitionView: View {
    let day: TrainingDay
    let nextBlock: TrainingBlock

    private var nextBlockNumber: Int {
        (day.blocks.firstIndex(where: { $0.id == nextBlock.id }) ?? 0) + 1
    }

    var body: some View {
        ZStack {
            Color(hex: "08090C").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("BLOCK COMPLETE")
                    .font(.oswald(fs(56), weight: .bold))
                    .foregroundColor(.white)
                    .tracking(3)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 28)

                Text("TRACK \(day.day)  ·  BLOCK \(nextBlockNumber)")
                    .font(.oswald(fs(18), weight: .semibold))
                    .foregroundColor(Color(hex: "22C55E"))
                    .tracking(2)

                Text(nextBlock.name.uppercased())
                    .font(.oswald(fs(32), weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .padding(.horizontal, 32)
                    .padding(.top, 6)

                if let desc = nextBlock.description {
                    Text(desc)
                        .font(.oswald(fs(16)))
                        .foregroundColor(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .lineLimit(3)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Session Complete Screen

struct SessionCompleteView: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let day: TrainingDay
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
                        Text("Day \(day.day)")
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
                    Text("Day \(day.day)")
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

// MARK: - Day Complete View

struct DayCompleteView: View {
    let stats: DayCompleteStats
    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @Environment(\.isLandscapeOrientation) var isLandscape

    var body: some View {
        if isLandscape {
            landscapeLayout
        } else {
            portraitLayout
        }
    }

    var portraitLayout: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(AppColors.accentLight).frame(width: 120, height: 120)
                    Image(systemName: "star.fill")
                        .font(.system(size: fs(64)))
                        .foregroundColor(AppColors.accentGreen)
                }
                .padding(.top, 32)

                Text("DAY \(stats.dayNumber) COMPLETE")
                    .font(.system(size: fs(36), weight: .black, design: .rounded))
                    .foregroundColor(AppColors.primaryBlack)
                    .multilineTextAlignment(.center)

                Text("Great work!")
                    .font(.system(size: fs(22), weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textMuted)
            }
            .frame(maxWidth: .infinity)

            Spacer()

            VStack(spacing: 0) {
                DayStatRow(label: "PUTTS", value: "\(stats.totalPutts)")
                Divider().padding(.horizontal, 8)
                DayStatRow(label: "ACCURACY", value: "\(stats.accuracyPercent)%")
                Divider().padding(.horizontal, 8)
                DayStatRow(label: "TIME", value: practiceTimeString)

                if let speed = stats.strongestSpeed {
                    Divider().padding(.horizontal, 8)
                    DayStatRow(label: "STRONGEST", value: "\(speed) MPH", valueColor: AppColors.accentGreen,
                               detail: "\(Int(stats.strongestAccuracy * 100))%")
                }
                if let speed = stats.weakestSpeed {
                    Divider().padding(.horizontal, 8)
                    DayStatRow(label: "NEEDS WORK", value: "\(speed) MPH", valueColor: AppColors.error,
                               detail: "\(Int(stats.weakestAccuracy * 100))%")
                }
                if let best = stats.bestBlock {
                    Divider().padding(.horizontal, 8)
                    DayStatRow(label: "BEST BLOCK", value: best, valueColor: AppColors.accentGreen)
                }
            }
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.border, lineWidth: 1))
            .padding(.horizontal, 16)

            Spacer()

            Button {
                trainingViewModel.endSession()
                trainingViewModel.shouldNavigateHome = true
            } label: {
                Text("Done")
                    .font(.system(size: fs(28), weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(AppColors.accentGreen)
                    .cornerRadius(18)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(AppColors.backgroundAlt.ignoresSafeArea())
    }

    var landscapeLayout: some View {
        GeometryReader { geo in
            HStack(spacing: 16) {
                VStack(spacing: 16) {
                    Spacer()
                    ZStack {
                        Circle().fill(AppColors.accentLight).frame(width: 100, height: 100)
                        Image(systemName: "star.fill").font(.system(size: fs(54))).foregroundColor(AppColors.accentGreen)
                    }
                    Text("DAY \(stats.dayNumber)\nCOMPLETE")
                        .font(.system(size: fs(30), weight: .black, design: .rounded))
                        .foregroundColor(AppColors.primaryBlack)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 10) {
                    VStack(spacing: 0) {
                        DayStatRowCompact(label: "PUTTS", value: "\(stats.totalPutts)")
                        Divider()
                        DayStatRowCompact(label: "ACCURACY", value: "\(stats.accuracyPercent)%")
                        Divider()
                        DayStatRowCompact(label: "TIME", value: practiceTimeString)
                        if let speed = stats.strongestSpeed {
                            Divider()
                            DayStatRowCompact(label: "STRONGEST", value: "\(speed) MPH", valueColor: AppColors.accentGreen)
                        }
                        if let speed = stats.weakestSpeed {
                            Divider()
                            DayStatRowCompact(label: "NEEDS WORK", value: "\(speed) MPH", valueColor: AppColors.error)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.border, lineWidth: 1))

                    Button {
                        trainingViewModel.endSession()
                        trainingViewModel.shouldNavigateHome = true
                    } label: {
                        Text("Done")
                            .font(.system(size: fs(24), weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.accentGreen)
                            .cornerRadius(16)
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
        .background(AppColors.backgroundAlt.ignoresSafeArea())
    }

    var practiceTimeString: String {
        if stats.practiceMinutes > 0 {
            return "\(stats.practiceMinutes)m \(stats.practiceSecondsRemainder)s"
        } else {
            return "\(stats.practiceSecondsRemainder)s"
        }
    }
}

// MARK: - Day Complete Stat Rows

struct DayStatRow: View {
    let label: String
    let value: String
    var valueColor: Color = AppColors.primaryBlack
    var detail: String? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: fs(20), weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textMuted)
                .tracking(1)
            Spacer()
            if let detail = detail {
                Text(detail)
                    .font(.system(size: fs(20), weight: .bold, design: .rounded))
                    .foregroundColor(valueColor.opacity(0.7))
                    .padding(.trailing, 6)
            }
            Text(value)
                .font(.system(size: fs(28), weight: .black, design: .rounded))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

struct DayStatRowCompact: View {
    let label: String
    let value: String
    var valueColor: Color = AppColors.primaryBlack

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: fs(16), weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textMuted)
                .tracking(1)
            Spacer()
            Text(value)
                .font(.system(size: fs(22), weight: .black, design: .rounded))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Reusable Session Components

/// Compact header — BLE status dot + day/block name. Scales up on iPad.
struct SessionHeaderCompact: View {
    let day: TrainingDay
    let block: TrainingBlock
    let bluetoothService: BluetoothService
    var adaptiveContext: String? = nil

    var blockNumber: Int {
        (day.blocks.firstIndex(where: { $0.id == block.id }) ?? 0) + 1
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.error)
                    .frame(width: 12, height: 12)
                Text("Day \(day.day): Block \(blockNumber): \(block.name)")
                    .font(.system(size: fs(24), weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.primaryBlack)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, adaptiveContext != nil ? 6 : 10)

            if let ctx = adaptiveContext {
                HStack(spacing: 5) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.accentGreen)
                    Text(ctx)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.accentGreen)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
        }
        .background(Color.white.ignoresSafeArea(edges: .top))
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .bottom)
    }
}

struct PressureHeaderCompact: View {
    let day: TrainingDay
    let block: TrainingBlock
    let bluetoothService: BluetoothService

    var blockNumber: Int {
        (day.blocks.firstIndex(where: { $0.id == block.id }) ?? 0) + 1
    }

    var body: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .font(.system(size: fs(24)))
                .foregroundColor(AppColors.error)
            Text("Day \(day.day): Block \(blockNumber): \(block.name)")
                .font(.system(size: fs(24), weight: .bold, design: .rounded))
                .foregroundColor(AppColors.error)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Spacer()
            Circle()
                .fill(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.error)
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.ignoresSafeArea(edges: .top))
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .bottom)
    }
}

struct GateTestHeaderCompact: View {
    let day: TrainingDay
    let block: TrainingBlock
    let bluetoothService: BluetoothService

    var blockNumber: Int {
        (day.blocks.firstIndex(where: { $0.id == block.id }) ?? 0) + 1
    }

    var body: some View {
        HStack {
            Image(systemName: "flag.checkered")
                .font(.system(size: fs(24)))
                .foregroundColor(AppColors.bleBlue)
            Text("Day \(day.day): Block \(blockNumber): \(block.name)")
                .font(.system(size: fs(24), weight: .bold, design: .rounded))
                .foregroundColor(AppColors.bleBlue)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Spacer()
            Circle()
                .fill(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.error)
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
struct ProgressBarMinimal: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(session.currentPutt)/\(session.totalPutts)")
                    .font(.system(size: fs(24), weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.primaryBlack)
                Spacer()
                Text("\(Int(session.zoneAccuracy * 100))%")
                    .font(.system(size: fs(28), weight: .black, design: .rounded))
                    .foregroundColor(AppColors.accentGreen)
            }
            ProgressBarView(current: session.currentPutt, total: session.totalPutts, color: AppColors.accentGreen)
                .frame(height: 14)
        }
        .padding(14)
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
                .font(.system(size: fs(24), weight: .bold, design: .rounded))
                .foregroundColor(AppColors.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
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

// MARK: - Backward-compatibility aliases

struct SessionHeader: View {
    let day: TrainingDay; let block: TrainingBlock; let bluetoothService: BluetoothService
    var body: some View { SessionHeaderCompact(day: day, block: block, bluetoothService: bluetoothService) }
}
struct PressureHeader: View {
    let day: TrainingDay; let block: TrainingBlock; let bluetoothService: BluetoothService
    var body: some View { PressureHeaderCompact(day: day, block: block, bluetoothService: bluetoothService) }
}
struct GateTestHeader: View {
    let day: TrainingDay; let block: TrainingBlock; let bluetoothService: BluetoothService
    var body: some View { GateTestHeaderCompact(day: day, block: block, bluetoothService: bluetoothService) }
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
