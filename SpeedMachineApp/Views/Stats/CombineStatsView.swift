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

    private var highScore: Int {
        Int(dataService.userProgress.combineHighScore)
    }

    private var averageScore: Double {
        guard !games.isEmpty else { return 0 }
        let total = games.reduce(0) { $0 + Int($1.totalScore) }
        return Double(total) / Double(games.count)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()

                ScrollView {
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
            .navigationTitle("Combine Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                games = statsService.getAllCombineGames()
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct CombineGameRow: View {
    let game: CombineGameData
    let isHighScore: Bool

    var body: some View {
        HStack(spacing: 14) {
            if isHighScore {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.orange)
                    .font(.headline)
            } else {
                Image(systemName: "target")
                    .foregroundColor(AppColors.textMuted)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Score: \(game.totalScore)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryBlack)

                if let date = game.playedAt {
                    Text(date.toDisplayString())
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
            }

            Spacer()

            if isHighScore {
                Text("Best")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 8)
    }
}
