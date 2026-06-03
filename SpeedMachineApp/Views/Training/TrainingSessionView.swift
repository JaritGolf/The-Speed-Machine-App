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
                    } else if let failResult = trainingViewModel.blockFailedResult {
                        BlockFailedView(result: failResult, block: block, day: day)
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
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: trainingViewModel.blockJustCompleted)
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

    /// PUTTS NEEDED = in-zone putts required to pass. Single source of truth lives on
    /// TrainingBlock so the display and the completion gate never diverge.
    private var passThreshold: Int {
        block.requiredInZonePutts(day: day.day, totalPutts: session.totalPutts)
    }

    var body: some View {
        SportLiveContainer(
            session: session,
            block: block,
            day: day,
            stripConfig: .standard(
                totalPutts: session.totalPutts,
                puttsTaken: session.currentPutt,
                inZone: session.inZonePutts,
                passThreshold: passThreshold
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
            stripConfig: .exploration(totalPutts: session.totalPutts, puttsTaken: session.currentPutt),
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

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme

    private var tokens: SportTokens {
        let isDark = (LiveViewTheme(rawValue: themeRaw) ?? .light).resolvedDark(scheme: colorScheme)
        return SportTokens.make(dark: isDark)
    }

    var lastPutt: PuttResult? { session.puttRecords.last }
    var isConsecutive: Bool { block.isConsecutiveChallenge }
    var goal: Int { block.consecutiveRequired ?? 5 }
    var totalLives: Int { block.lives ?? 3 }

    private var pressureLabel: String { isConsecutive ? "DON'T BREAK" : "HOLD STEADY" }
    private var lastPuttLabel: String {
        if !isConsecutive, let p = lastPutt, !p.isInZone { return "LAST PUTT — COST A LIFE" }
        return "LAST PUTT"
    }

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                SportRecHeader(
                    day: day,
                    block: block,
                    tokens: tokens,
                    icon: .bolt,
                    isConnected: bluetoothService.isConnected
                )

                if isConsecutive {
                    thresholdStrip
                    challengeHero
                } else {
                    puttsBanner
                    livesHero
                }

                // Chromeless target + putt glide animation (red pressure label).
                SportHeroCard(session: session, tokens: tokens, tolerance: 0.5,
                              targetLabel: pressureLabel,
                              targetLabelColor: AppColors.error,
                              lastPuttLabel: lastPuttLabel)
                    .frame(maxHeight: .infinity)

                SportEndButton(tokens: tokens, showAlert: $showEndSessionAlert, title: "END PRESSURE")
                    .padding(.horizontal, 22)
                    .padding(.top, 4)
                    .padding(.bottom, 22)
            }

            SportEdgeFlash(
                lastPuttID: session.puttRecords.count,
                inZone: session.puttRecords.last?.isInZone
            )
        }
        .alert("End Session?", isPresented: $showEndSessionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { trainingViewModel.endSession() }
        } message: {
            Text("Are you sure you want to end this pressure challenge? Your progress will be saved.")
        }
    }

    // PUTTS LEFT banner (lives variant)
    @ViewBuilder
    private var puttsBanner: some View {
        VStack(spacing: 4) {
            Text("PUTTS LEFT")
                .font(.inter(fs(14), weight: .heavy))
                .foregroundColor(tokens.sub)
                .tracking(fs(14) * 0.22)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%02d", max(0, session.totalPutts - session.currentPutt)))
                    .font(.inter(fs(84)))
                    .foregroundColor(tokens.fg)
                    .monospacedDigit()
                Text("/ \(session.totalPutts)")
                    .font(.inter(fs(84)))
                    .foregroundColor(tokens.sub)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .overlay(Rectangle().fill(tokens.hairline).frame(height: 1), alignment: .bottom)
    }

    // Hearts hero (lives variant)
    @ViewBuilder
    private var livesHero: some View {
        VStack(spacing: 14) {
            Text("LIVES REMAINING")
                .font(.inter(fs(20), weight: .heavy))
                .foregroundColor(tokens.sub)
                .tracking(fs(20) * 0.22)
            HStack(spacing: 18) {
                ForEach(0..<totalLives, id: \.self) { i in
                    Image(systemName: i < session.livesRemaining ? "heart.fill" : "heart")
                        .font(.system(size: fs(40)))
                        .foregroundColor(i < session.livesRemaining ? tokens.miss : tokens.subtle)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    // STREAK / PUTTS TAKEN strip (consecutive variant)
    @ViewBuilder
    private var thresholdStrip: some View {
        HStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("STREAK")
                    .font(.inter(fs(20), weight: .heavy))
                    .foregroundColor(tokens.sub)
                    .tracking(fs(20) * 0.16)
                Text("\(session.consecutiveSuccesses)")
                    .font(.inter(fs(36)))
                    .foregroundColor(tokens.fg)
                    .monospacedDigit()
                Text("/")
                    .font(.inter(fs(22), weight: .heavy))
                    .foregroundColor(tokens.sub)
                Text("\(goal)")
                    .font(.inter(fs(22), weight: .heavy))
                    .foregroundColor(tokens.sub)
                    .monospacedDigit()
            }
            Rectangle().fill(tokens.hairline).frame(width: 1, height: fs(34))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("PUTTS TAKEN")
                    .font(.inter(fs(20), weight: .heavy))
                    .foregroundColor(tokens.sub)
                    .tracking(fs(20) * 0.16)
                Text(String(format: "%02d", session.currentPutt))
                    .font(.inter(fs(36)))
                    .foregroundColor(tokens.fg)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .overlay(Rectangle().fill(tokens.hairline).frame(height: 1), alignment: .bottom)
    }

    // Consecutive dots hero
    @ViewBuilder
    private var challengeHero: some View {
        VStack(spacing: 14) {
            Text("HIT \(goal) IN A ROW")
                .font(.inter(fs(20), weight: .heavy))
                .foregroundColor(tokens.fg)
                .tracking(fs(20) * 0.22)
            HStack(spacing: 14) {
                ForEach(0..<goal, id: \.self) { i in
                    let hit = i < session.consecutiveSuccesses
                    ZStack {
                        Circle().fill(hit ? tokens.zone : Color.clear)
                        Circle().stroke(hit ? tokens.zone : tokens.subtle, lineWidth: 2.5)
                        if hit {
                            Image(systemName: "checkmark")
                                .font(.system(size: fs(20), weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: fs(48), height: fs(48))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 12)
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
                totalPutts: session.totalPutts,
                puttsTaken: session.currentPutt,
                inZone: session.inZonePutts,
                passThreshold: passMin
            ),
            headerIcon: .flag,
            endTitle: "END GATE TEST",
            endAccent: AppColors.bleBlue
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

                        if result.passed, let nextDay = trainingViewModel.nextTrackForAutoAdvance {
                            TrackAdvanceFooter(
                                nextDay: nextDay,
                                fg: AppColors.primaryBlack,
                                track: AppColors.border,
                                accent: AppColors.accentGreen,
                                onExit: { trainingViewModel.endSession() }
                            )
                        } else {
                            Button {
                                trainingViewModel.endSession()
                            } label: {
                                Text(result.passed ? "Continue" : "Try Again Later")
                                    .font(.system(size: fs(28), weight: .bold, design: .rounded))
                                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                                    .background(AppColors.accentGreen).cornerRadius(18)
                            }
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

                if result.passed, let nextDay = trainingViewModel.nextTrackForAutoAdvance {
                    TrackAdvanceFooter(
                        nextDay: nextDay,
                        fg: AppColors.primaryBlack,
                        track: AppColors.border,
                        accent: AppColors.accentGreen,
                        onExit: { trainingViewModel.endSession() }
                    )
                } else {
                    Button {
                        trainingViewModel.endSession()
                    } label: {
                        Text(result.passed ? "Continue" : "Try Again Later")
                            .font(.system(size: fs(28), weight: .bold, design: .rounded))
                            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 20)
                            .background(AppColors.accentGreen).cornerRadius(18)
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Block Failed Screen

/// Shown when a standard block misses its in-zone threshold. Offers Try Again (restart
/// the same block in place) and Exit (return home). Built on the Sport live-view design
/// architecture: theme-aware SportTokens, Inter type, big monospaced stat readout.
struct BlockFailedView: View {
    let result: BlockFailResult
    let block: TrainingBlock
    let day: TrainingDay
    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isLandscapeOrientation) var isLandscape

    private var tokens: SportTokens {
        let isDark = (LiveViewTheme(rawValue: themeRaw) ?? .light).resolvedDark(scheme: colorScheme)
        return SportTokens.make(dark: isDark)
    }

    private var blockNumber: Int {
        (day.blocks.firstIndex(where: { $0.id == block.id }) ?? 0) + 1
    }

    private var subtitle: String {
        block.onFail ?? "Land \(result.required) in the zone to pass."
    }

    // MARK: Pieces

    private func badge(_ size: CGFloat) -> some View {
        ZStack {
            Circle().fill(tokens.miss.opacity(tokens.isDark ? 0.16 : 0.10))
            Circle().stroke(tokens.miss.opacity(0.45), lineWidth: 2)
            Image(systemName: "xmark")
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundColor(tokens.miss)
        }
        .frame(width: size, height: size)
    }

    private var titleStack: some View {
        VStack(spacing: fs(8)) {
            Text("BLOCK FAILED")
                .font(.inter(fs(40)))
                .foregroundColor(tokens.miss)
                .tracking(fs(40) * 0.04)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text("T\(day.day) · BLOCK \(blockNumber) · \(block.name.uppercased())")
                .font(.inter(fs(13), weight: .heavy))
                .foregroundColor(tokens.sub)
                .tracking(fs(13) * 0.10)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    // Big monospaced IN ZONE readout: achieved in miss, required in sub.
    private var statBlock: some View {
        VStack(spacing: fs(6)) {
            Text("IN ZONE")
                .font(.inter(fs(20), weight: .heavy))
                .foregroundColor(tokens.sub)
                .tracking(fs(20) * 0.16)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(result.inZone)")
                    .font(.inter(fs(84)))
                    .foregroundColor(tokens.miss)
                    .monospacedDigit()
                Text(" / \(result.required)")
                    .font(.inter(fs(42), weight: .heavy))
                    .foregroundColor(tokens.sub)
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.4)
        }
    }

    private var subtitleText: some View {
        Text(subtitle)
            .font(.inter(fs(18), weight: .medium))
            .foregroundColor(tokens.sub)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var tryAgainButton: some View {
        Button {
            trainingViewModel.retryBlock()
        } label: {
            Text("TRY AGAIN")
                .font(.inter(fs(20), weight: .heavy))
                .foregroundColor(tokens.isDark ? Color(hex: "08090C") : .white)
                .tracking(fs(20) * 0.16)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(tokens.zone)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var exitButton: some View {
        Button {
            trainingViewModel.endSession()
        } label: {
            Text("EXIT")
                .font(.inter(fs(20), weight: .heavy))
                .foregroundColor(tokens.sub)
                .tracking(fs(20) * 0.22)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(tokens.subtle, lineWidth: 1.5))
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            if isLandscape {
                GeometryReader { geo in
                    HStack(spacing: 24) {
                        VStack(spacing: fs(18)) {
                            Spacer()
                            badge(120)
                            titleStack
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        VStack(spacing: fs(20)) {
                            Spacer()
                            statBlock
                            subtitleText
                            VStack(spacing: 12) { tryAgainButton; exitButton }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, max(12, geo.safeAreaInsets.bottom))
                    .padding(.leading, max(24, geo.safeAreaInsets.leading + 12))
                    .padding(.trailing, max(24, geo.safeAreaInsets.trailing + 12))
                }
                .ignoresSafeArea(edges: .horizontal)
            } else {
                VStack(spacing: fs(28)) {
                    Spacer()
                    badge(150)
                    titleStack
                    statBlock
                    subtitleText.padding(.horizontal, 8)
                    Spacer()
                    VStack(spacing: 12) { tryAgainButton; exitButton }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Track Auto-Advance Footer

/// Countdown wheel + "UP NEXT: Track N" + Exit, shown on a completion screen while the
/// next track is queued to auto-start. Visual only — the ViewModel owns the authoritative
/// 5s timer; `onExit` cancels it. Palette is supplied by the host so it reads on both the
/// black DayCompleteView and the white GateTestResultView.
struct TrackAdvanceFooter: View {
    let nextDay: TrainingDay
    var total: Int = 5
    let fg: Color
    let track: Color
    let accent: Color
    let onExit: () -> Void

    @State private var countdown: Int
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(nextDay: TrainingDay, total: Int = 5, fg: Color, track: Color, accent: Color, onExit: @escaping () -> Void) {
        self.nextDay = nextDay
        self.total = total
        self.fg = fg
        self.track = track
        self.accent = accent
        self.onExit = onExit
        _countdown = State(initialValue: total)
    }

    private var firstBlockName: String { nextDay.blocks.first?.name ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            Text("UP NEXT")
                .font(.inter(fs(11), weight: .bold))
                .kerning(2.2)
                .foregroundColor(accent)
                .padding(.bottom, 10)

            Text("Track \(nextDay.day)".uppercased())
                .font(.inter(fs(34)))
                .foregroundColor(fg)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if !firstBlockName.isEmpty {
                Text(firstBlockName.uppercased())
                    .font(.inter(fs(13), weight: .bold))
                    .foregroundColor(fg.opacity(0.55))
                    .kerning(0.8)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 6)
            }

            ZStack {
                Circle()
                    .stroke(track, lineWidth: 5)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: CGFloat(countdown) / CGFloat(total))
                    .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: countdown)
                Text("\(countdown)")
                    .font(.inter(fs(36)))
                    .foregroundColor(fg)
            }
            .padding(.top, 24)

            Text("STARTING IN")
                .font(.inter(fs(11), weight: .bold))
                .kerning(2.0)
                .foregroundColor(fg.opacity(0.50))
                .padding(.top, 10)
                .padding(.bottom, 28)

            Button(action: onExit) {
                Text("Exit to Tracks →")
                    .font(.inter(fs(17), weight: .bold))
                    .foregroundColor(fg.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(Capsule().stroke(track, lineWidth: 1.5))
            }
            .padding(.horizontal, 32)
        }
        .onReceive(timer) { _ in
            if countdown > 0 { countdown -= 1 }
        }
    }
}

// MARK: - Block Transition Screen

struct BlockTransitionView: View {
    let day: TrainingDay
    let nextBlock: TrainingBlock

    @State private var countdown: Int = 3
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var nextBlockNumber: Int {
        (day.blocks.firstIndex(where: { $0.id == nextBlock.id }) ?? 0) + 1
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: fs(60), weight: .bold))
                    .foregroundColor(AppColors.accentGreen)
                    .padding(.bottom, 20)

                Text("BLOCK COMPLETE")
                    .font(.inter(fs(32)))
                    .foregroundColor(.white)
                    .kerning(1.5)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("Track \(day.day)  ·  Block \(nextBlockNumber) of \(day.blocks.count)")
                    .font(.inter(fs(13), weight: .bold))
                    .foregroundColor(.white.opacity(0.50))
                    .kerning(0.8)
                    .padding(.top, 8)
                    .padding(.bottom, 32)

                Text("UP NEXT")
                    .font(.inter(fs(11), weight: .bold))
                    .kerning(2.2)
                    .foregroundColor(AppColors.accentGreen)
                    .padding(.bottom, 10)

                Text(nextBlock.name.uppercased())
                    .font(.inter(fs(48)))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
                    .lineLimit(2)
                    .padding(.horizontal, 32)

                Text("Track \(day.day) · Block \(nextBlockNumber) · \(nextBlock.putts ?? 0) Putts".uppercased())
                    .font(.inter(fs(11), weight: .bold))
                    .foregroundColor(.white.opacity(0.50))
                    .kerning(0.8)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.bottom, 36)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 5)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: CGFloat(countdown) / 3.0)
                        .stroke(AppColors.accentGreen, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    Text("\(countdown)")
                        .font(.inter(fs(36)))
                        .foregroundColor(.white)
                }

                Text("STARTING IN")
                    .font(.inter(fs(11), weight: .bold))
                    .kerning(2.0)
                    .foregroundColor(.white.opacity(0.50))
                    .padding(.top, 10)

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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 40)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: fs(60), weight: .bold))
                        .foregroundColor(AppColors.accentGreen)
                        .padding(.bottom, 16)

                    Text("TRACK COMPLETE")
                        .font(.inter(fs(32)))
                        .foregroundColor(.white)
                        .kerning(1.5)

                    Text("Track \(stats.dayNumber)")
                        .font(.inter(fs(16), weight: .regular))
                        .foregroundColor(.white.opacity(0.60))
                        .padding(.top, 6)
                        .padding(.bottom, 24)

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%02d", stats.dayNumber))
                            .font(.inter(fs(80)))
                            .foregroundColor(.white)
                        Text("/ 30")
                            .font(.inter(fs(24), weight: .bold))
                            .foregroundColor(.white.opacity(0.50))
                    }

                    Text("TRACKS COMPLETE")
                        .font(.inter(fs(13), weight: .bold))
                        .kerning(2.0)
                        .foregroundColor(.white.opacity(0.50))
                        .padding(.top, 4)
                        .padding(.bottom, 32)

                    HStack(spacing: 0) {
                        trackStatCell(label: "PUTTS", value: "\(stats.totalPutts)")
                        Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 40)
                        trackStatCell(label: "ACCURACY", value: "\(stats.accuracyPercent)%")
                        Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 40)
                        trackStatCell(label: "TIME", value: practiceTimeString)
                    }
                    .padding(.bottom, 40)

                    if let nextDay = trainingViewModel.nextTrackForAutoAdvance {
                        // Auto-advancing into the next track — countdown wheel + exit.
                        TrackAdvanceFooter(
                            nextDay: nextDay,
                            fg: .white,
                            track: Color.white.opacity(0.12),
                            accent: AppColors.accentGreen,
                            onExit: {
                                trainingViewModel.endSession()
                                trainingViewModel.shouldNavigateHome = true
                            }
                        )
                        .padding(.bottom, 40)
                    } else {
                        // Final track (no next) — plain exit.
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
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }

    private func trackStatCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.inter(fs(22)))
                .foregroundColor(.white)
            Text(label)
                .font(.inter(fs(10), weight: .bold))
                .kerning(1.5)
                .foregroundColor(.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity)
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
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(AppColors.border)
                        .frame(height: 14)
                    RoundedRectangle(cornerRadius: 7)
                        .fill(AppColors.accentGreen)
                        .frame(width: session.totalPutts > 0 ? geo.size.width * CGFloat(session.currentPutt) / CGFloat(session.totalPutts) : 0, height: 14)
                }
            }
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
