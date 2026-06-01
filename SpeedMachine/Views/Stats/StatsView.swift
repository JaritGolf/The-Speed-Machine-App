//
//  StatsView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

// MARK: - Stats Dashboard (Root Screen)

struct StatsDashboardView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss

    @State private var showTrends = false
    @State private var showSessionHistory = false
    @State private var showCombineStats = false
    @State private var selectedSpeedProfile: SpeedProfileData?

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Whoop-style top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    Spacer()
                    Text("STATS")
                        .font(.custom("Inter-Bold", size: 13))
                        .kerning(2.5)
                        .foregroundColor(.black)
                    Spacer()
                    Color.clear.frame(width: 28, height: 28)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 12)

                Divider().overlay(AppColors.border)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        KeyMetricsSection()
                        if !statsService.weakestSpeeds.isEmpty {
                            NeedsWorkCard()
                        }
                        SpeedLadderSection(selectedProfile: $selectedSpeedProfile)
                        VStack(spacing: 12) {
                            QuickLinkButton(
                                title: "Trends Over Time",
                                subtitle: "Accuracy, consistency & practice charts",
                                icon: "chart.line.uptrend.xyaxis",
                                color: AppColors.accentGreen
                            ) { showTrends = true }
                            QuickLinkButton(
                                title: "Session History",
                                subtitle: "Putt-by-putt deep dives",
                                icon: "list.bullet.rectangle",
                                color: AppColors.bleBlue
                            ) { showSessionHistory = true }
                            QuickLinkButton(
                                title: "Combine Stats",
                                subtitle: "Game scores & zone breakdown",
                                icon: "target",
                                color: .orange
                            ) { showCombineStats = true }
                        }
                    }
                    .padding()
                    .adaptiveContentFrame(maxWidth: 700)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            StatsTabBar(active: .stats) { tab in
                switch tab {
                case .trends:  showTrends = true
                case .history: showSessionHistory = true
                case .combine: showCombineStats = true
                case .stats:   break
                }
            }
        }
        .fullScreenCover(isPresented: $showTrends) { TrendsView() }
        .fullScreenCover(isPresented: $showSessionHistory) { SessionHistoryView() }
        .fullScreenCover(isPresented: $showCombineStats) { CombineStatsView() }
        .sheet(item: $selectedSpeedProfile) { profile in SpeedDetailView(profile: profile) }
    }
}

// MARK: - Key Metrics Section

struct KeyMetricsSection: View {
    @EnvironmentObject var statsService: StatsService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryBlack)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: isIPad ? 4 : 2), spacing: 12) {
                MetricCard(
                    label: "Accuracy",
                    value: String(format: "%.0f%%", statsService.overallAccuracy),
                    icon: "target",
                    color: accuracyColor(statsService.overallAccuracy)
                )

                MetricCard(
                    label: "Total Putts",
                    value: formatNumber(statsService.totalLifetimePutts),
                    icon: "figure.golf",
                    color: AppColors.accentGreen
                )

                MetricCard(
                    label: "Consistency",
                    value: statsService.overallConsistency > 0 ?
                        String(format: "%.2f", statsService.overallConsistency) : "—",
                    icon: "waveform.path",
                    color: AppColors.bleBlue
                )

                MetricCard(
                    label: "Day Streak",
                    value: "\(statsService.currentPracticeStreak)",
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
    }

    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 75 { return AppColors.accentGreen }
        if accuracy >= 50 { return .orange }
        return AppColors.error
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000.0)
        }
        return "\(n)"
    }
}

struct MetricCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }

            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundColor(AppColors.primaryBlack)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Needs Work Card

struct NeedsWorkCard: View {
    @EnvironmentObject var statsService: StatsService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.headline)
                Text("Needs Work")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryBlack)
            }

            Text("Focus practice on these speeds to improve:")
                .font(.subheadline)
                .foregroundColor(AppColors.textMuted)

            HStack(spacing: 10) {
                ForEach(statsService.weakestSpeeds, id: \.targetSpeed) { profile in
                    WeakSpeedPill(profile: profile)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct WeakSpeedPill: View {
    let profile: SpeedProfileData

    var body: some View {
        VStack(spacing: 4) {
            Text("\(profile.targetSpeed) MPH")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundColor(AppColors.error)

            Text(String(format: "%.0f%%", profile.accuracy))
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColors.error.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Speed Ladder Section (Hero Visual)

struct SpeedLadderSection: View {
    @EnvironmentObject var statsService: StatsService
    @Binding var selectedProfile: SpeedProfileData?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Speed Ladder")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryBlack)

                Spacer()

                Text("Tap for details")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }

            VStack(spacing: 6) {
                ForEach(statsService.sortedProfiles, id: \.targetSpeed) { profile in
                    SpeedLadderRow(profile: profile)
                        .onTapGesture {
                            selectedProfile = profile
                        }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

struct SpeedLadderRow: View {
    let profile: SpeedProfileData

    private var accuracyColor: Color {
        let acc = profile.accuracy
        if profile.totalPutts == 0 { return AppColors.textMuted.opacity(0.3) }
        if acc >= 80 { return AppColors.accentGreen }
        if acc >= 65 { return AppColors.accentBright }
        if acc >= 50 { return .yellow }
        if acc >= 35 { return .orange }
        return AppColors.error
    }

    private var barWidth: CGFloat {
        if profile.totalPutts == 0 { return 0 }
        return CGFloat(profile.accuracy / 100.0)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Speed label
            Text("\(profile.targetSpeed)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundColor(AppColors.primaryBlack)
                .frame(width: 28, alignment: .trailing)

            // Accuracy bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(AppColors.backgroundAlt)
                        .frame(height: 24)
                        .cornerRadius(4)

                    // Filled bar
                    Rectangle()
                        .fill(accuracyColor)
                        .frame(width: geometry.size.width * barWidth, height: 24)
                        .cornerRadius(4)
                }
            }
            .frame(height: 24)

            // Accuracy percentage
            if profile.totalPutts > 0 {
                Text(String(format: "%.0f%%", profile.accuracy))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundColor(accuracyColor)
                    .frame(width: 40, alignment: .trailing)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Quick Link Button

struct QuickLinkButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryBlack)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textMuted)
                    .font(.caption)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Make SpeedProfileData identifiable for sheet presentation

extension SpeedProfileData: Identifiable {
    public var id: Int16 { targetSpeed }
}

// MARK: - Stats Tab Bar

enum StatsTab {
    case stats, trends, history, combine
}

struct StatsTabBar: View {
    let active: StatsTab
    let onTap: (StatsTab) -> Void

    private let tabs: [(StatsTab, String)] = [
        (.stats,   "STATS"),
        (.trends,  "TRENDS"),
        (.history, "HISTORY"),
        (.combine, "COMBINE")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(tabs, id: \.1) { tab, label in
                    Button { onTap(tab) } label: {
                        VStack(spacing: 6) {
                            Text(label)
                                .font(.custom("Inter-Bold", size: 11))
                                .kerning(1.0)
                                .foregroundColor(active == tab ? .black : AppColors.textSubdued)
                            Rectangle()
                                .fill(active == tab ? Color.black : Color.clear)
                                .frame(height: 2)
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 22)
            .background(Color.white)
        }
    }
}
