//
//  SpeedDetailView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

struct SpeedDetailView: View {
    let profile: SpeedProfileData
    @Environment(\.dismiss) var dismiss

    private var zone: SpeedZone {
        SpeedZone.getZone(for: Int(profile.targetSpeed))
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Hero speed + accuracy
                        SpeedHeroCard(profile: profile, zone: zone)

                        // Detailed Metrics
                        DetailedMetricsCard(profile: profile)

                        // Tendency indicator
                        TendencyCard(profile: profile)

                        // Streak info
                        StreakCard(profile: profile)
                    }
                    .padding()
                }
            }
            .navigationTitle("\(profile.targetSpeed) MPH")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Speed Hero Card

struct SpeedHeroCard: View {
    let profile: SpeedProfileData
    let zone: SpeedZone

    private var accuracyColor: Color {
        let acc = profile.accuracy
        if acc >= 80 { return AppColors.accentGreen }
        if acc >= 65 { return AppColors.accentBright }
        if acc >= 50 { return .yellow }
        if acc >= 35 { return .orange }
        return AppColors.error
    }

    var body: some View {
        VStack(spacing: 16) {
            // Big accuracy number
            Text(profile.totalPutts > 0 ? String(format: "%.0f%%", profile.accuracy) : "—")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundColor(profile.totalPutts > 0 ? accuracyColor : AppColors.textMuted)

            Text("Accuracy")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textMuted)

            // Zone badge
            HStack(spacing: 6) {
                Text(zone.name)
                    .font(.caption)
                    .fontWeight(.semibold)

                Text("•")

                Text("\(zone.speedRange.lowerBound)–\(zone.speedRange.upperBound) MPH")
                    .font(.caption)
            }
            .foregroundColor(AppColors.textMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppColors.backgroundAlt)
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Detailed Metrics

struct DetailedMetricsCard: View {
    let profile: SpeedProfileData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance")
                .font(.headline)
                .foregroundColor(AppColors.primaryBlack)

            VStack(spacing: 12) {
                DetailRow(
                    label: "Total Putts",
                    value: "\(profile.totalPutts)"
                )
                DetailRow(
                    label: "On Target",
                    value: "\(profile.onTargetPutts)"
                )
                DetailRow(
                    label: "Average Deviation",
                    value: profile.totalPutts > 0 ?
                        String(format: "%.2f MPH", profile.averageDeviation) : "—"
                )
                DetailRow(
                    label: "Consistency (Std Dev)",
                    value: profile.totalPutts > 1 ?
                        String(format: "%.2f MPH", profile.standardDeviation) : "—"
                )
                DetailRow(
                    label: "Average Actual Speed",
                    value: profile.totalPutts > 0 ?
                        String(format: "%.1f MPH", profile.averageActualSpeed) : "—"
                )

                if let lastPracticed = profile.lastPracticedAt {
                    DetailRow(
                        label: "Last Practiced",
                        value: lastPracticed.toDisplayString()
                    )
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

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.textMuted)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.primaryBlack)
        }
    }
}

// MARK: - Tendency Card

struct TendencyCard: View {
    let profile: SpeedProfileData

    private var iconName: String {
        let signed = profile.averageSignedDeviation
        if abs(signed) < 0.1 { return "equal.circle.fill" }
        return signed > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }

    private var tendencyColor: Color {
        let signed = profile.averageSignedDeviation
        if abs(signed) < 0.1 { return AppColors.accentGreen }
        if abs(signed) < 0.3 { return .orange }
        return AppColors.error
    }

    var body: some View {
        guard profile.totalPutts > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            HStack(spacing: 14) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(tendencyColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Miss Tendency")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryBlack)

                    Text(profile.tendencyDescription)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        )
    }
}

// MARK: - Streak Card

struct StreakCard: View {
    let profile: SpeedProfileData

    var body: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(profile.currentStreak)")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundColor(AppColors.primaryBlack)
                Text("Current Streak")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)

            VStack(spacing: 4) {
                Text("\(profile.bestStreak)")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundColor(AppColors.accentGreen)
                Text("Best Streak")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }
            .frame(maxWidth: .infinity)
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
