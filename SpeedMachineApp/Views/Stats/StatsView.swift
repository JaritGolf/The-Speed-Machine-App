//
//  StatsView.swift
//  SpeedMachine
//
//  Whoop minimal Stats Dashboard (mockup 14).
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

    @AppStorage("hasSeenStatsTour") private var seenStatsTour = false
    @State private var statsTourIndex: Int? = nil
    private let statsTourSteps = TourCopy.stats

    private func fmtPutts(_ n: Int) -> (String, String) {
        n >= 1000 ? (String(format: "%.1f", Double(n) / 1000.0), "k") : ("\(n)", "")
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                StatsHeader(title: "STATS") { dismiss() }

                ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // KPI 3-up
                        HStack(alignment: .top, spacing: 24) {
                            KpiCell(value: "\(Int(statsService.overallAccuracy))", unit: "%", label: "ACCURACY")
                            let p = fmtPutts(statsService.totalLifetimePutts)
                            KpiCell(value: p.0, unit: p.1, label: "PUTTS")
                            KpiCell(value: "\(statsService.currentPracticeStreak)", unit: " day", label: "STREAK")
                        }
                        .coachmarkAnchor(0)
                        .id(0)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 22)

                        // Needs Work
                        if !statsService.weakestSpeeds.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("NEEDS WORK")
                                    .font(.custom("Inter-Bold", size: 14))
                                    .kerning(2.1)
                                    .foregroundColor(AppColors.accentAmber)
                                HStack(spacing: 0) {
                                    ForEach(Array(statsService.weakestSpeeds.prefix(3).enumerated()), id: \.element.targetSpeed) { index, p in
                                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                                            Text("\(p.targetSpeed)")
                                                .font(.custom("Inter-Black", size: 24))
                                                .foregroundColor(AppColors.error)
                                            Text("MPH")
                                                .font(.custom("Inter-Bold", size: 13))
                                                .foregroundColor(AppColors.error)
                                            Text("\(Int(p.accuracy))%")
                                                .font(.custom("Inter-Bold", size: 14))
                                                .foregroundColor(AppColors.textSubdued)
                                        }
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        if index < statsService.weakestSpeeds.prefix(3).count - 1 {
                                            Spacer(minLength: 12)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
                        }

                        // Speed Ladder header
                        HStack {
                            Text("SPEED LADDER")
                                .font(.custom("Inter-Bold", size: 18))
                                .kerning(2.0)
                                .foregroundColor(AppColors.textSubdued)
                            Spacer()
                            Text("TAP FOR MORE")
                                .font(.custom("Inter-Bold", size: 13))
                                .kerning(1.0)
                                .foregroundColor(Color(hex: "d4d4d4"))
                        }
                        .coachmarkAnchor(1)
                        .id(1)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 10)
                        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)

                        // Ladder rows
                        ForEach(statsService.sortedProfiles, id: \.targetSpeed) { profile in
                            SpeedLadderRow(profile: profile)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedSpeedProfile = profile }
                        }
                    }
                    .padding(.bottom, 16)
                }
                .onChange(of: statsTourIndex) { _, i in
                    if let i { withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(i, anchor: .center) } }
                }
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
            .coachmarkAnchor(2)
        }
        .coachmarkTour(statsTourSteps, index: $statsTourIndex, style: .appColors()) {
            seenStatsTour = true
            statsTourIndex = nil
        }
        .onAppear {
            if !seenStatsTour && statsTourIndex == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if !seenStatsTour { statsTourIndex = 0 }
                }
            }
        }
        .fullScreenCover(isPresented: $showTrends) { TrendsView() }
        .fullScreenCover(isPresented: $showSessionHistory) { SessionHistoryView() }
        .fullScreenCover(isPresented: $showCombineStats) { CombineStatsView() }
        .sheet(item: $selectedSpeedProfile) { profile in SpeedDetailView(profile: profile) }
    }
}

// MARK: - Shared stats pieces

/// Accuracy → tier color (mockup g/a/r): ≥70 green, ≥50 amber, else red.
func statAccuracyColor(_ accuracy: Double) -> Color {
    if accuracy >= 75 { return AppColors.accentGreen }
    if accuracy >= 50 { return AppColors.accentAmber }
    return AppColors.error
}

struct StatsHeader: View {
    let title: String
    let onBack: () -> Void
    var body: some View {
        ZStack {
            Text(title)
                .font(.custom("Inter-Bold", size: 16))
                .kerning(3)
                .foregroundColor(.black)
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(.black)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .bottom)
    }
}

struct KpiCell: View {
    let value: String
    let unit: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value)
                    .font(.custom("Inter-Black", size: 28))
                    .foregroundColor(.black)
                Text(unit)
                    .font(.custom("Inter-Bold", size: 15))
                    .foregroundColor(AppColors.textSubdued)
            }
            Text(label)
                .font(.custom("Inter-Bold", size: 10))
                .kerning(2.0)
                .foregroundColor(AppColors.textSubdued)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SpeedLadderRow: View {
    let profile: SpeedProfileData

    private var hasData: Bool { profile.totalPutts > 0 }
    private var color: Color { statAccuracyColor(profile.accuracy) }

    var body: some View {
        HStack(spacing: 16) {
            Text("\(profile.targetSpeed)")
                .font(.custom("Inter-Black", size: 22))
                .foregroundColor(.black)
                .lineLimit(1)
                .fixedSize()
                .frame(width: 34, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.border).frame(height: 7)
                    if hasData {
                        Capsule().fill(color)
                            .frame(width: max(0, min(1, profile.accuracy / 100.0)) * geo.size.width, height: 7)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 24)

            Text(hasData ? "\(Int(profile.accuracy))%" : "—")
                .font(.custom("Inter-Bold", size: 16))
                .foregroundColor(hasData ? color : Color(hex: "d4d4d4"))
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 11)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
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
        HStack(spacing: 0) {
            ForEach(tabs, id: \.1) { tab, label in
                Button { onTap(tab) } label: {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(active == tab ? Color.black : Color.clear)
                            .frame(height: 2)
                        Text(label)
                            .font(.custom("Inter-Bold", size: 13))
                            .kerning(1.2)
                            .foregroundColor(active == tab ? .black : Color(hex: "c8c8c8"))
                            .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color.white)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }
}
