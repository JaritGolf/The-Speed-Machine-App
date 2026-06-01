//
//  SpeedDetailView.swift
//  SpeedMachine
//
//  Whoop minimal per-speed detail (mockup 16).
//

import SwiftUI

struct SpeedDetailView: View {
    let profile: SpeedProfileData
    @Environment(\.dismiss) var dismiss

    private var zone: SpeedZone { SpeedZone.getZone(for: Int(profile.targetSpeed)) }
    private var hasData: Bool { profile.totalPutts > 0 }
    private var accColor: Color { statAccuracyColor(profile.accuracy) }

    private var signed: Double { profile.averageSignedDeviation }
    private var tendencyColor: Color {
        if abs(signed) < 0.1 { return AppColors.accentGreen }
        return signed > 0 ? AppColors.error : AppColors.bleBlue
    }
    private var tendencyArrow: String { abs(signed) < 0.1 ? "→" : (signed > 0 ? "↑" : "↓") }
    private var tendencyLabel: String {
        if abs(signed) < 0.1 { return "On Target" }
        return signed > 0 ? "Trending Fast" : "Trending Slow"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                StatsHeader(title: "\(profile.targetSpeed) MPH") { dismiss() }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Accuracy hero
                        VStack(spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text(hasData ? "\(Int(profile.accuracy))" : "—")
                                    .font(.custom("Inter-Black", size: 80))
                                    .foregroundColor(hasData ? accColor : AppColors.textSubdued)
                                if hasData {
                                    Text("%")
                                        .font(.custom("Inter-Black", size: 40))
                                        .foregroundColor(hasData ? accColor : AppColors.textSubdued)
                                }
                            }
                            Text("ACCURACY")
                                .font(.custom("Inter-Bold", size: 13))
                                .kerning(2.4)
                                .foregroundColor(AppColors.textSubdued)
                            Text("\(zone.name.uppercased()) · \(zone.speedRange.lowerBound)–\(zone.speedRange.upperBound) MPH")
                                .font(.custom("Inter-Bold", size: 12))
                                .kerning(1.0)
                                .foregroundColor(AppColors.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 26)
                        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .bottom)

                        // KPI 3-up
                        HStack(alignment: .top, spacing: 24) {
                            KpiCell(value: "\(profile.totalPutts)", unit: "", label: "PUTTS")
                            KpiCell(value: hasData ? String(format: "%+.2f", signed) : "—", unit: "", label: "AVG MISS")
                            KpiCell(value: profile.totalPutts > 1 ? String(format: "%.2f", profile.standardDeviation) : "—", unit: "", label: "STD DEV")
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 22)

                        // Tendency
                        if hasData {
                            HStack(spacing: 16) {
                                Text(tendencyArrow)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(tendencyColor)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tendencyLabel)
                                        .font(.custom("Inter-Bold", size: 15))
                                        .foregroundColor(tendencyColor)
                                    Text(String(format: "Averaging %+.2f MPH vs target", signed))
                                        .font(.custom("Inter-SemiBold", size: 12))
                                        .foregroundColor(AppColors.textSubdued)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 18)
                            .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
                        }

                        // Streaks
                        HStack(spacing: 0) {
                            VStack(spacing: 8) {
                                Text("\(profile.currentStreak)")
                                    .font(.custom("Inter-Black", size: 40))
                                    .foregroundColor(.black)
                                Text("CURRENT STREAK")
                                    .font(.custom("Inter-Bold", size: 11))
                                    .kerning(2.0)
                                    .foregroundColor(AppColors.textSubdued)
                            }
                            .frame(maxWidth: .infinity)
                            .overlay(Rectangle().fill(AppColors.border).frame(width: 1), alignment: .trailing)
                            VStack(spacing: 8) {
                                Text("\(profile.bestStreak)")
                                    .font(.custom("Inter-Black", size: 40))
                                    .foregroundColor(AppColors.accentGreen)
                                Text("BEST STREAK")
                                    .font(.custom("Inter-Bold", size: 11))
                                    .kerning(2.0)
                                    .foregroundColor(AppColors.textSubdued)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 20)
                        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
                    }
                }
            }
        }
    }
}
