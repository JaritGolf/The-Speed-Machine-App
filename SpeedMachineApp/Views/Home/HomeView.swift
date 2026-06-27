//
//  HomeView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var combineViewModel: CombineViewModel
    @EnvironmentObject var recallViewModel: RecallViewModel
    @EnvironmentObject var practiceViewModel: PracticeViewModel
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var statsService: StatsService

    @State private var showConnectionView = false
    @State private var didAttemptAutoConnect = false
    @State private var didAutoPromptConnection = false
    @State private var showTrainingView = false
    @State private var showCombineView = false
    @State private var showRecallView = false
    @State private var showPracticeView = false
    @State private var showProgressView = false
    @State private var showStatsView = false
    @State private var showSettingsView = false

    // First-launch coachmark tour
    @AppStorage("hasSeenTour") private var hasSeenTour = false
    @State private var tourStep: TourStep? = nil

    // Milestone unlock celebration popup
    @State private var pendingCelebration: UnlockMilestone? = nil

    /// Phase 5 migration screen — shown once after recomputeFromHistory() runs.
    private var currentTrack: Int { Int(dataService.userProgress.currentDay) }
    private var completedTracks: Int { dataService.getAllCompletedDays().count }
    /// The 30-track program is finished — surface the Maintenance / Daily Tune-Up row.
    private var programComplete: Bool { currentTrack > TrainingConstants.totalTracks }
    /// Phase 1 ends at the Zone 2 Gate Test (track 11). Until it's passed, every Home
    /// feature except the training program is locked so new users build experience first.
    private var phase1Passed: Bool { dataService.hasPassedGateTest(gateId: "gate-zone2") }
    private var progressFraction: Double { Double(completedTracks) / Double(TrainingConstants.totalTracks) }
    private var accuracyPct: Int { Int(statsService.overallAccuracy) }
    private var totalPutts: Int { statsService.totalLifetimePutts }
    private var streak: Int { statsService.currentPracticeStreak }

    // Focus bars: 3 weakest speeds + 2 best speeds, each a single MPH value.
    private var focusBars: [(speed: Int, accuracy: Double, hasData: Bool)] {
        let weak = statsService.weakestSpeeds.prefix(3)
        let weakSet = Set(weak.map { $0.targetSpeed })
        // "Best" = strongest speeds that aren't already shown as weakest; take 2.
        let best = statsService.strongestSpeeds
            .filter { !weakSet.contains($0.targetSpeed) }
            .prefix(2)

        var bars: [(speed: Int, accuracy: Double, hasData: Bool)] = []
        for p in weak { bars.append((Int(p.targetSpeed), p.accuracy, true)) }
        for p in best { bars.append((Int(p.targetSpeed), p.accuracy, true)) }
        // Pad to a stable 5 slots so layout doesn't jump before enough data exists.
        while bars.count < 5 { bars.append((0, 0, false)) }
        return bars
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                topNavBar
                bleStrip
                    .tourAnchor(.pair)
                Divider().overlay(AppColors.border)
                scrollContent
            }
        }
        .overlayPreferenceValue(TourAnchorKey.self) { anchors in
            if tourStep != nil {
                OnboardingTourOverlay(
                    anchors: anchors,
                    step: $tourStep,
                    onFinish: {
                        hasSeenTour = true
                        tourStep = nil
                    }
                )
            }
        }
        .overlay {
            if let milestone = pendingCelebration {
                UnlockCelebrationModal(milestone: milestone) {
                    dataService.recordShownUnlockCelebration(id: milestone.id)
                    pendingCelebration = nil
                    // Surface the next pending unlock, if several landed at once.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { checkPendingCelebration() }
                }
            }
        }
        .fullScreenCover(isPresented: $showConnectionView) { ConnectionView() }
        .fullScreenCover(isPresented: $showTrainingView) { DaySelectionView() }
        .fullScreenCover(isPresented: $showCombineView) { CombineModeView() }
        .fullScreenCover(isPresented: $showRecallView) { RecallModeView() }
        .fullScreenCover(isPresented: $showPracticeView) { PracticeModeView() }
        .fullScreenCover(isPresented: $showProgressView) { ProgressDashboardView() }
        .fullScreenCover(isPresented: $showStatsView) { StatsDashboardView() }
        .fullScreenCover(isPresented: $showSettingsView) { SettingsView() }
        .onAppear {
            // First-launch coachmark tour — runs once after WelcomeView.
            if !hasSeenTour && tourStep == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if !hasSeenTour { tourStep = .pair }
                }
            }

            checkPendingCelebration()

            // Try to connect silently on launch. No screen unless this fails.
            guard !didAttemptAutoConnect else { return }
            didAttemptAutoConnect = true
            if !bluetoothService.isConnected
                && bluetoothService.connectionState != .connecting
                && bluetoothService.connectionState != .reconnecting {
                bluetoothService.startScanning()
            }
        }
        .onChange(of: bluetoothService.isScanning) { _, scanning in
            // The silent scan finished. If we still aren't connected (or connecting),
            // surface the pair screen once — the "problem case" the user asked for.
            // Suppressed while the first-launch tour is running so it can't cover it.
            guard hasSeenTour, tourStep == nil else { return }
            guard !scanning, !didAutoPromptConnection else { return }
            if !bluetoothService.isConnected
                && bluetoothService.connectionState != .connecting
                && bluetoothService.connectionState != .reconnecting
                && !showConnectionView {
                didAutoPromptConnection = true
                showConnectionView = true
            }
        }
        .onChange(of: showTrainingView) { _, shown in
            // Unlocks all happen inside Training; check when the player returns to Home.
            if !shown { checkPendingCelebration() }
        }
        .onChange(of: hasSeenTour) { _, seen in
            // "Replay all tutorials" (Settings) resets this flag — re-fire the home tour,
            // since onAppear doesn't run again when the Settings cover dismisses.
            if !seen && tourStep == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !hasSeenTour { tourStep = .pair }
                }
            }
        }
    }

    // MARK: - Unlock celebration

    /// Presents a one-time congrats popup for any milestone newly unlocked since last seen.
    /// A first-run backfill marks already-achieved milestones as shown so existing players
    /// don't get retroactive popups.
    private func checkPendingCelebration() {
        guard hasSeenTour, tourStep == nil, pendingCelebration == nil else { return }

        let achieved = UnlockMilestone.allCases.filter {
            $0.isAchieved(passedGates: dataService.getPassedGateTests(),
                          currentDay: currentTrack,
                          totalTracks: TrainingConstants.totalTracks,
                          maxTrainedSpeed: recallViewModel.maxTrainedSpeed)
        }

        if !dataService.unlockCelebrationsBackfilled {
            achieved.forEach { dataService.recordShownUnlockCelebration(id: $0.id) }
            dataService.unlockCelebrationsBackfilled = true
            return
        }

        if let next = achieved.first(where: { !dataService.hasShownUnlockCelebration(id: $0.id) }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pendingCelebration = next }
        }
    }

    // MARK: - Top Nav Bar

    private var topNavBar: some View {
        HStack(spacing: 10) {
            Image("SpeedMachineLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 30)

            Text("THE SPEED MACHINE")
                .font(.custom("Inter-ExtraBold", size: 17))
                .kerning(3.0)
                .foregroundColor(.black)

            Spacer()

            cloudSyncBadge

            Button { showSettingsView = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.black)
            }
            .tourAnchor(.settings)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.white)
    }

    @ViewBuilder
    private var cloudSyncBadge: some View {
        switch dataService.cloudKitSyncStatus {
        case .idle:
            Image(systemName: "icloud.fill")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textMuted)
                .padding(.trailing, 4)
        case .syncing:
            ProgressView()
                .scaleEffect(0.75)
                .tint(AppColors.accentGreen)
                .padding(.trailing, 4)
        case .synced:
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 15))
                .foregroundColor(AppColors.accentGreen)
                .padding(.trailing, 4)
        case .error:
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.system(size: 15))
                .foregroundColor(AppColors.error)
                .padding(.trailing, 4)
        }
    }

    // MARK: - BLE Device Strip

    private var bleStrip: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textMuted)
                .frame(width: 8, height: 8)
                .shadow(color: bluetoothService.isConnected ? AppColors.accentGreen.opacity(0.4) : .clear,
                        radius: 4, x: 0, y: 0)

            Text(bluetoothService.isConnected ? "SPEED MACHINE · CONNECTED" : "SPEED MACHINE · NOT CONNECTED")
                .font(.custom("Inter-Bold", size: 11))
                .kerning(2.0)
                .foregroundColor(AppColors.textMuted)

            Spacer()

            if bluetoothService.isConnected && bluetoothService.batteryLevel > 0 {
                Text("BATT \(bluetoothService.batteryLevel)%")
                    .font(.custom("Inter-Bold", size: 11))
                    .kerning(1.5)
                    .foregroundColor(AppColors.textMuted)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(Color.white)
        .onTapGesture { showConnectionView = true }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        heroSection
                        Divider().overlay(AppColors.border)
                        kpiRow
                        Divider().overlay(AppColors.border)
                        focusSection
                    }
                    .tourAnchor(.dashboard)
                    .id(TourStep.dashboard)

                    Divider().overlay(AppColors.border)
                    if programComplete {
                        maintenanceRow
                        Divider().overlay(AppColors.border)
                    }
                    recallRow
                        .tourAnchor(.recall)
                        .id(TourStep.recall)
                    Divider().overlay(AppColors.border)
                    practiceRow
                        .tourAnchor(.practice)
                        .id(TourStep.practice)
                    Divider().overlay(AppColors.border)
                    combineRow
                        .tourAnchor(.combine)
                        .id(TourStep.combine)
                    Divider().overlay(AppColors.border)
                    statsRow
                        .tourAnchor(.stats)
                        .id(TourStep.stats)
                    Divider().overlay(AppColors.border)
                    ctaSection
                        .tourAnchor(.start)
                        .id(TourStep.start)
                }
            }
            .onChange(of: tourStep) { _, step in
                guard let step else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(step, anchor: .center)
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TRACK")
                .font(.custom("Inter-Bold", size: 11))
                .kerning(2.5)
                .foregroundColor(AppColors.textSubdued)
                .padding(.top, 22)
                .padding(.bottom, 8)

            HStack(alignment: .bottom, spacing: 12) {
                Text(String(format: "%02d", currentTrack))
                    .font(.custom("Inter-Black", size: 96))
                    .foregroundColor(.black)
                    .lineSpacing(0)
                    .tracking(-4)
                    .baselineOffset(0)

                Text("of 30")
                    .font(.custom("Inter-Bold", size: 18))
                    .foregroundColor(AppColors.textSubdued)
                    .padding(.bottom, 12)
            }

            if let blockSub = currentBlockSubtitle {
                Text(blockSub)
                    .font(.custom("Inter-SemiBold", size: 13))
                    .foregroundColor(AppColors.textMuted)
                    .padding(.top, 2)
            }

            progressBarThin
                .padding(.top, 14)
                .padding(.bottom, 22)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currentBlockSubtitle: String? {
        guard let program = TrainingProgramLoader.shared.program,
              currentTrack > 0, currentTrack <= program.days.count else { return nil }
        let track = program.days[currentTrack - 1]
        let blockCount = track.blocks.count
        return "Track \(currentTrack) · \(blockCount) Blocks · \(track.title)"
    }

    private var progressBarThin: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.border)
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.accentGreen)
                    .frame(width: max(0, geo.size.width * progressFraction), height: 4)
            }
        }
        .frame(height: 4)
    }

    // MARK: - KPI Row

    private var kpiRow: some View {
        HStack(spacing: 0) {
            kpiCell(value: "\(accuracyPct)%", label: "ACCURACY")
            Divider().frame(height: 40).overlay(AppColors.border)
            kpiCell(value: totalPutts >= 1000
                    ? String(format: "%.1fk", Double(totalPutts) / 1000)
                    : "\(totalPutts)",
                    label: "PUTTS")
            Divider().frame(height: 40).overlay(AppColors.border)
            kpiCell(value: "\(streak)", label: "DAY STREAK")
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
    }

    private func kpiCell(value: String, label: String) -> some View {
        VStack(alignment: .center, spacing: 5) {
            Text(value)
                .font(.custom("Inter-Black", size: 28))
                .foregroundColor(.black)
                .tracking(-0.5)
            Text(label)
                .font(.custom("Inter-Bold", size: 10))
                .kerning(2.0)
                .foregroundColor(AppColors.textSubdued)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Focus Section

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FOCUS — YOUR SPEEDS")
                .font(.custom("Inter-Bold", size: 11))
                .kerning(2.2)
                .foregroundColor(AppColors.textSubdued)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(focusBars.enumerated()), id: \.offset) { _, bar in
                    VStack(spacing: 4) {
                        // MPH number on top, colored by make-%.
                        Text(bar.hasData ? "\(bar.speed)" : "—")
                            .font(.custom("Inter-Bold", size: 15))
                            .foregroundColor(bar.hasData ? statAccuracyColor(bar.accuracy) : AppColors.textMuted)

                        // Make-% underneath, smaller, same tint.
                        Text(bar.hasData ? "\(Int(bar.accuracy))%" : " ")
                            .font(.custom("Inter-Bold", size: 9))
                            .foregroundColor(bar.hasData ? statAccuracyColor(bar.accuracy) : .clear)

                        GeometryReader { geo in
                            let maxH = geo.size.height
                            let heightFraction = bar.hasData ? max(0.15, bar.accuracy / 100.0) : 0.25
                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(bar.hasData ? statAccuracyColor(bar.accuracy) : Color(hex: "e5e5e5"))
                                    .frame(height: maxH * heightFraction)
                            }
                        }
                        .frame(height: 36)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Group labels: first three columns = WEAKEST, last two = BEST.
            // Widths mirror the 5-column bar grid above (spacing 4) so they line up.
            GeometryReader { geo in
                let spacing: CGFloat = 4
                let colW = (geo.size.width - spacing * 4) / 5
                HStack(spacing: spacing) {
                    Text("WEAKEST")
                        .font(.custom("Inter-Bold", size: 9))
                        .kerning(1.2)
                        .foregroundColor(AppColors.textSubdued)
                        .frame(width: colW * 3 + spacing * 2, alignment: .center)
                    Text("BEST")
                        .font(.custom("Inter-Bold", size: 9))
                        .kerning(1.2)
                        .foregroundColor(AppColors.textSubdued)
                        .frame(width: colW * 2 + spacing, alignment: .center)
                }
            }
            .frame(height: 12)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
    }

    // MARK: - Module Link Rows

    /// Shared layout for the tappable feature rows. When `locked`, the subtitle and
    /// trailing accessory are replaced by a "PASS PHASE 1 TO UNLOCK" lock treatment
    /// (matches the lock style used in CombineModeView) and the tap is disabled.
    @ViewBuilder
    private func moduleRow(title: String,
                           subtitle: String,
                           locked: Bool,
                           trailingValue: String? = nil,
                           action: @escaping () -> Void) -> some View {
        Button { if !locked { action() } } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.custom("Inter-Bold", size: 11))
                        .kerning(2.2)
                        .foregroundColor(AppColors.textSubdued)

                    if locked {
                        HStack(spacing: 5) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .semibold))
                            Text("PASS PHASE 1 TO UNLOCK")
                                .font(.custom("Inter-Bold", size: 11))
                                .kerning(1.5)
                        }
                        .foregroundColor(AppColors.textSubdued)
                    } else {
                        Text(subtitle)
                            .font(.custom("Inter-Bold", size: 11))
                            .kerning(1.5)
                            .foregroundColor(AppColors.textMuted)
                    }
                }

                Spacer()

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSubdued)
                } else {
                    HStack(spacing: 10) {
                        if let trailingValue {
                            Text(trailingValue)
                                .font(.custom("Inter-Black", size: 22))
                                .foregroundColor(.black)
                                .tracking(-0.4)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSubdued)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .opacity(locked ? 0.7 : 1.0)
        }
        .disabled(locked)
    }

    private var recallRow: some View {
        moduleRow(title: "CALL THE SPEED",
                  subtitle: "COLD RECALL · HIT IT FROM FEEL",
                  locked: !phase1Passed,
                  trailingValue: recallViewModel.bestScore > 0 ? "\(recallViewModel.bestScore)%" : nil) {
            showRecallView = true
        }
    }

    private var practiceRow: some View {
        moduleRow(title: "FREE PRACTICE",
                  subtitle: "PICK A SPEED · HIT YOUR PUTTS",
                  locked: !phase1Passed) {
            showPracticeView = true
        }
    }

    private var maintenanceRow: some View {
        Button {
            if bluetoothService.isConnected {
                recallViewModel.startMaintenanceRound()
            }
            showRecallView = true
        } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAILY TUNE-UP")
                        .font(.custom("Inter-Bold", size: 11))
                        .kerning(2.2)
                        .foregroundColor(AppColors.accentAmber)
                    Text(maintenanceSubtitle)
                        .font(.custom("Inter-Bold", size: 11))
                        .kerning(1.5)
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSubdued)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
    }

    private var maintenanceSubtitle: String {
        let focus = statsService.maintenanceFocusSpeeds
        guard !focus.isEmpty else { return "KEEP YOUR SPEEDS SHARP" }
        return "FOCUS · " + focus.map { "\($0)" }.joined(separator: " · ") + " MPH"
    }

    private var combineRow: some View {
        moduleRow(title: "COMBINE",
                  subtitle: "HIGH SCORE",
                  locked: !phase1Passed,
                  trailingValue: "\(combineViewModel.highScore)") {
            showCombineView = true
        }
    }

    private var statsRow: some View {
        moduleRow(title: "STATS",
                  subtitle: "LIFETIME · TRENDS · HISTORY",
                  locked: !phase1Passed) {
            showStatsView = true
        }
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 10) {
            Button { showTrainingView = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Continue Training")
                        .font(.custom("Inter-Bold", size: 16))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(AppColors.accentGreen)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            Text("\(completedTracks) OF \(TrainingConstants.totalTracks) · \(Int(progressFraction * 100))% COMPLETE")
                .font(.custom("Inter-Bold", size: 10))
                .kerning(2.2)
                .foregroundColor(AppColors.textSubdued)
                .padding(.bottom, 32)
        }
    }
}

