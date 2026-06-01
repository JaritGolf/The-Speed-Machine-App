//
//  ProgressView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

struct ProgressDashboardView: View {
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss

    var completedDays: [DayCompletionData] {
        dataService.getAllCompletedDays()
    }

    var recentSessions: [SessionData] {
        dataService.getRecentSessions(limit: 10)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Overall Stats Card
                        OverallStatsCard()

                        // Zone Progress Card
                        ZoneProgressCard()

                        // Recent Sessions
                        RecentSessionsCard()
                    }
                    .padding()
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct OverallStatsCard: View {
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var combineViewModel: CombineViewModel

    var completedDays: Int {
        dataService.getAllCompletedDays().count
    }

    var totalPutts: Int {
        Int(dataService.userProgress.totalPutts)
    }

    var currentDay: Int {
        Int(dataService.userProgress.currentDay)
    }

    var progressPercentage: Int {
        Int((Double(completedDays) / Double(TrainingConstants.totalTracks)) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Overall Progress")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryBlack)

            // Main Progress Ring or Bar
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(progressPercentage)%")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.accentGreen)

                        Text("Complete")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textMuted)
                    }

                    Spacer()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.border)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.accentGreen)
                            .frame(width: max(0, geo.size.width * (Double(completedDays) / Double(TrainingConstants.totalTracks))))
                    }
                }
                .frame(height: 12)
            }

            Divider()

            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatBox(title: "Days Complete", value: "\(completedDays)/\(TrainingConstants.totalTracks)")
                StatBox(title: "Current Day", value: "\(currentDay)")
                StatBox(title: "Total Putts", value: "\(totalPutts)")
                StatBox(title: "High Score", value: "\(combineViewModel.highScore)")
            }
        }
        .padding()
        .cardStyle()
    }
}

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundColor(AppColors.primaryBlack)

            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.backgroundAlt)
        .cornerRadius(12)
    }
}

struct ZoneProgressCard: View {
    @EnvironmentObject var dataService: DataService

    var unlockedZones: [Int16] {
        dataService.userProgress.unlockedZones ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Zone Progress")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryBlack)

            VStack(spacing: 12) {
                ForEach(SpeedZone.zones, id: \.number) { zone in
                    ZoneRow(zone: zone, isUnlocked: unlockedZones.contains(Int16(zone.number)))
                }
            }
        }
        .padding()
        .cardStyle()
    }
}

struct ZoneRow: View {
    let zone: SpeedZone
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? AppColors.accentGreen : AppColors.textMuted.opacity(0.3))
                    .frame(width: 50, height: 50)

                if isUnlocked {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(zone.name)
                    .font(.headline)
                    .foregroundColor(AppColors.primaryBlack)

                Text("\(zone.speedRange.lowerBound)-\(zone.speedRange.upperBound) MPH • ±\(zone.tolerance, specifier: "%.1f") MPH")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }

            Spacer()

            if isUnlocked {
                Text("\(zone.multiplier, specifier: "%.1f")x")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(AppColors.accentGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.accentLight)
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(isUnlocked ? Color.white : AppColors.backgroundAlt.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUnlocked ? AppColors.border : Color.clear, lineWidth: 1)
        )
    }
}

struct RecentSessionsCard: View {
    @EnvironmentObject var dataService: DataService

    var recentSessions: [SessionData] {
        dataService.getRecentSessions(limit: 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Sessions")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryBlack)

            if recentSessions.isEmpty {
                Text("No sessions yet")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textMuted)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(recentSessions, id: \.id) { session in
                        SessionRowView(session: session)
                    }
                }
            }
        }
        .padding()
        .cardStyle()
    }
}

struct SessionRowView: View {
    let session: SessionData

    var accuracy: Int {
        guard session.completedPutts > 0 else { return 0 }
        return Int((Float(session.onTargetPutts) / Float(session.completedPutts)) * 100)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accuracy >= 70 ? AppColors.accentLight : AppColors.backgroundAlt)
                    .frame(width: 40, height: 40)

                Text("\(accuracy)%")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundColor(accuracy >= 70 ? AppColors.accentGreen : AppColors.textMuted)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Day \(session.dayNumber) • \(session.blockId ?? "Block")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryBlack)

                if let date = session.startedAt {
                    Text(date.toDisplayString())
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
            }

            Spacer()

            Text("\(session.onTargetPutts)/\(session.completedPutts)")
                .font(.subheadline)
                .foregroundColor(AppColors.textMuted)
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
