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
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var statsService: StatsService

    @State private var showConnectionView = false
    @State private var showTrainingView = false
    @State private var showCombineView = false
    @State private var showProgressView = false
    @State private var showStatsView = false
    @State private var showSettingsView = false
    /// Phase 5 migration screen — shown once after recomputeFromHistory() runs.
    @State private var showSkillReassessment = false

    private var currentTrack: Int { Int(dataService.userProgress.currentDay) }
    private var completedTracks: Int { dataService.getAllCompletedTracks().count }
    private var progressFraction: Double { Double(completedTracks) / Double(TrainingConstants.totalTracks) }
    private var accuracyPct: Int { Int(statsService.overallAccuracy) }
    private var totalPutts: Int { statsService.totalLifetimePutts }
    private var streak: Int { statsService.currentPracticeStreak }

    // Zone accuracy (average across speeds in each zone)
    private var zoneAccuracies: [(label: String, accuracy: Double, hasPutts: Bool)] {
        let groups: [(String, [Int])] = [
            ("3-7",   [3,4,5,6,7]),
            ("8-10",  [8,9,10]),
            ("11-14", [11,12,13,14]),
            ("15-18", [15,16,17,18]),
            ("19-20", [19,20])
        ]
        return groups.map { label, speeds in
            let profiles = speeds.compactMap { statsService.speedProfiles[$0] }
            let withPutts = profiles.filter { $0.totalPutts > 0 }
            let avg = withPutts.isEmpty ? 0.0 : withPutts.map { $0.accuracy }.reduce(0, +) / Double(withPutts.count)
            return (label, avg, !withPutts.isEmpty)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                topNavBar
                bleStrip
                Divider().overlay(AppColors.border)
                scrollContent
            }
        }
        .fullScreenCover(isPresented: $showConnectionView) { ConnectionView() }
        .fullScreenCover(isPresented: $showTrainingView) { TrackSelectionView() }
        .fullScreenCover(isPresented: $showCombineView) { CombineModeView() }
        .fullScreenCover(isPresented: $showProgressView) { ProgressDashboardView() }
        .fullScreenCover(isPresented: $showStatsView) { StatsDashboardView() }
        .fullScreenCover(isPresented: $showSettingsView) { SettingsView() }
        .fullScreenCover(isPresented: $showSkillReassessment) {
            SkillReassessmentView(isPresented: $showSkillReassessment)
        }
        .onAppear {
            let mastery = MasteryService.shared
            if !mastery.hasRecomputedFromHistory {
                mastery.recomputeFromHistory()
                showSkillReassessment = true
            }
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

            Button { showSettingsView = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.white)
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection
                Divider().overlay(AppColors.border)
                kpiRow
                Divider().overlay(AppColors.border)
                focusSection
                Divider().overlay(AppColors.border)
                combineRow
                Divider().overlay(AppColors.border)
                statsRow
                Divider().overlay(AppColors.border)
                ctaSection
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
              currentTrack > 0, currentTrack <= program.tracks.count else { return nil }
        let track = program.tracks[currentTrack - 1]
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
            Text("FOCUS — WEAKEST SPEEDS")
                .font(.custom("Inter-Bold", size: 11))
                .kerning(2.2)
                .foregroundColor(AppColors.textSubdued)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(zoneAccuracies, id: \.label) { zone in
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            let maxH = geo.size.height
                            let heightFraction = zone.hasPutts ? max(0.15, zone.accuracy / 100.0) : 0.25
                            let isWeak = zone.hasPutts && zone.accuracy < 75.0
                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(isWeak ? AppColors.accentAmber : Color(hex: "e5e5e5"))
                                    .frame(height: maxH * heightFraction)
                            }
                        }
                        .frame(height: 36)

                        Text(zone.label)
                            .font(.custom("Inter-Bold", size: 9))
                            .kerning(0.5)
                            .foregroundColor(AppColors.textSubdued)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
    }

    // MARK: - Module Link Rows

    private var combineRow: some View {
        Button { showCombineView = true } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("COMBINE")
                        .font(.custom("Inter-Bold", size: 11))
                        .kerning(2.2)
                        .foregroundColor(AppColors.textSubdued)
                    Text("HIGH SCORE")
                        .font(.custom("Inter-Bold", size: 11))
                        .kerning(1.5)
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                HStack(spacing: 10) {
                    Text("\(combineViewModel.highScore)")
                        .font(.custom("Inter-Black", size: 22))
                        .foregroundColor(.black)
                        .tracking(-0.4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSubdued)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
    }

    private var statsRow: some View {
        Button { showStatsView = true } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STATS")
                        .font(.custom("Inter-Bold", size: 11))
                        .kerning(2.2)
                        .foregroundColor(AppColors.textSubdued)
                    Text("LIFETIME · TRENDS · HISTORY")
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

