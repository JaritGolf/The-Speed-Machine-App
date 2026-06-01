//
//  SkillReassessmentView.swift
//  SpeedMachine
//
//  Phase 5 — One-time migration screen shown on the first launch after the
//  skill-gating system ships.
//
//  Triggered by: HomeView on appear when MasteryService.recomputeFromHistory()
//  just ran (i.e. the migration key was not yet set).
//
//  Shows: per-speed mastery tier, brief explanation of the new system,
//  and a single "Got it — Let's Build" button that dismisses permanently.
//
//  Per SKILL_GATING_PLAN.md §5: "frames any apparent regression as
//  'this is what the data actually says — let's build it back.'"
//

import SwiftUI

struct SkillReassessmentView: View {
    @Binding var isPresented: Bool

    private let mastery = MasteryService.shared

    // Group speeds into rows of 3 for the tier grid
    private var speedTierRows: [[Int]] {
        let speeds = Array(3...15)
        return stride(from: 0, to: speeds.count, by: 3).map {
            Array(speeds[$0..<min($0 + 3, speeds.count)])
        }
    }

    var body: some View {
        ZStack {
            AppColors.backgroundAlt.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ────────────────────────────────────────────────
                VStack(spacing: 10) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(AppColors.accentGreen)
                        .padding(.top, 40)

                    Text("Your Skill Snapshot")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.primaryBlack)

                    Text("We've analysed your putting history and mapped your current skill level at each speed. Going forward, training blocks adapt to what the data actually says.")
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(AppColors.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }
                .padding(.bottom, 12)

                // ── Speed tier grid ───────────────────────────────────────
                ScrollView {
                    VStack(spacing: 10) {
                        // Tier legend
                        HStack(spacing: 8) {
                            ForEach([
                                ("T0", "Unpracticed", Color.gray.opacity(0.4)),
                                ("T1", "Familiar",    Color.yellow.opacity(0.7)),
                                ("T2", "Competent",   Color.orange.opacity(0.8)),
                                ("T3", "Proficient",  Color.green.opacity(0.7)),
                                ("T4", "Mastered",    AppColors.accentGreen),
                            ], id: \.0) { label, name, color in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 10, height: 10)
                                    Text(label)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppColors.textMuted)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))

                        // Speed rows
                        ForEach(speedTierRows, id: \.first) { row in
                            HStack(spacing: 10) {
                                ForEach(row, id: \.self) { speed in
                                    SpeedTierCell(speed: speed,
                                                  tier: mastery.tier(forSpeed: speed))
                                }
                                // Pad last row if fewer than 3 speeds
                                if row.count < 3 {
                                    ForEach(0..<(3 - row.count), id: \.self) { _ in
                                        Spacer().frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }

                        // Reassurance note
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.accentGreen)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your progress is safe")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.primaryBlack)
                                Text("Tracks you've already completed stay completed. Skill levels only affect future blocks — not what you've already done.")
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(AppColors.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.border, lineWidth: 1))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }

                // ── CTA button ────────────────────────────────────────────
                Button {
                    isPresented = false
                } label: {
                    Text("Got it — Let's Build")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(AppColors.accentGreen)
                        .cornerRadius(18)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Speed Tier Cell

private struct SpeedTierCell: View {
    let speed: Int
    let tier: MasteryTier

    private var tierColor: Color {
        switch tier {
        case .unpracticed: return Color.gray.opacity(0.35)
        case .familiar:    return Color.yellow.opacity(0.65)
        case .competent:   return Color.orange.opacity(0.75)
        case .proficient:  return Color.green.opacity(0.65)
        case .mastered:    return AppColors.accentGreen
        }
    }

    private var tierLabel: String { tier.shortName }

    var body: some View {
        VStack(spacing: 5) {
            Text("\(speed)")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(AppColors.primaryBlack)
            Text("MPH")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.textMuted)
                .tracking(1)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tierColor)
                    .frame(height: 28)
                Text(tierLabel)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.border, lineWidth: 1))
    }
}
