//
//  CombineStatsView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

struct CombineStatsView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss

    @State private var games: [CombineGameData] = []
    @State private var showTrends = false
    @State private var showHistory = false

    private var highScore: Int {
        Int(dataService.userProgress.combineHighScore)
    }

    private var averageScore: Double {
        guard !games.isEmpty else { return 0 }
        let total = games.reduce(0) { $0 + Int($1.totalScore) }
        return Double(total) / Double(games.count)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    Spacer()
                    Text("COMBINE")
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
                        if games.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: "target")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppColors.textMuted.opacity(0.5))

                                Text("No Combine games yet")
                                    .font(.headline)
                                    .foregroundColor(AppColors.primaryBlack)

                                Text("Play the Combine to see your score history here.")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textMuted)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(Color.white)
                            .cornerRadius(12)
                        } else {
                            // Summary metrics
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                MetricCard(
                                    label: "High Score",
                                    value: "\(highScore)",
                                    icon: "trophy.fill",
                                    color: .orange
                                )

                                MetricCard(
                                    label: "Avg Score",
                                    value: String(format: "%.0f", averageScore),
                                    icon: "chart.bar.fill",
                                    color: AppColors.accentGreen
                                )

                                MetricCard(
                                    label: "Games",
                                    value: "\(games.count)",
                                    icon: "gamecontroller.fill",
                                    color: AppColors.bleBlue
                                )
                            }

                            // Score trend (mini chart)
                            if games.count >= 2 {
                                let sortedGames = games.sorted { ($0.playedAt ?? Date()) < ($1.playedAt ?? Date()) }
                                TrendChartCard(
                                    title: "Score Trend",
                                    subtitle: "Combine score over time",
                                    data: sortedGames.map {
                                        TrendPoint(date: $0.playedAt ?? Date(), value: Double($0.totalScore))
                                    },
                                    valueFormat: "%.0f pts",
                                    color: .orange,
                                    idealDirection: .up
                                )
                            }

                            // Game history
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Game History")
                                    .font(.headline)
                                    .foregroundColor(AppColors.primaryBlack)

                                ForEach(games, id: \.id) { game in
                                    CombineGameRow(game: game, isHighScore: Int(game.totalScore) == highScore)
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
                    .padding()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            StatsTabBar(active: .combine) { tab in
                switch tab {
                case .stats:   dismiss()
                case .trends:  showTrends = true
                case .history: showHistory = true
                case .combine: break
                }
            }
        }
        .fullScreenCover(isPresented: $showTrends) { TrendsView() }
        .fullScreenCover(isPresented: $showHistory) { SessionHistoryView() }
        .onAppear { games = statsService.getAllCombineGames() }
    }
}

struct CombineGameRow: View {
    let game: CombineGameData
    let isHighScore: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(game.totalScore)")
                .font(.custom("Inter-Black", size: 22))
                .foregroundColor(.black)
                .tracking(-0.5)
                .frame(width: 64, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                if let date = game.playedAt {
                    Text(date.toDisplayString().uppercased())
                        .font(.custom("Inter-Bold", size: 11))
                        .kerning(1.0)
                        .foregroundColor(AppColors.textSubdued)
                }
            }

            Spacer()

            if isHighScore {
                Text("BEST")
                    .font(.custom("Inter-Bold", size: 9))
                    .kerning(1.0)
                    .foregroundColor(AppColors.accentAmber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AppColors.accentAmber, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }
}
