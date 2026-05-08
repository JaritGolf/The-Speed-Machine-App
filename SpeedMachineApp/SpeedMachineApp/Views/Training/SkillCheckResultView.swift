//
//  SkillCheckResultView.swift
//  SpeedMachine
//
//  Phase 3 — Soft Gate UI.
//  Shown when a block's zone accuracy falls below its pass threshold.
//  User can choose to Repeat the block (default) or Continue anyway (override).
//
//  Designed for 5–6 foot viewing distance per CLAUDE.md viewing-distance rule.
//  Primary numbers: ≥ 80pt black weight. Labels: ≥ 24pt bold.
//

import SwiftUI

struct SkillCheckResultView: View {
    let evaluation: BlockEvaluation
    let session: SessionProgress
    let block: TrainingBlock
    let track: TrainingTrack

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    private var achievedPercent: Int { Int(evaluation.zoneAccuracy * 100) }
    private var targetPercent: Int   { Int(evaluation.threshold   * 100) }
    private var gapPercent: Int      { targetPercent - achievedPercent }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────────────
            SessionHeaderCompact(track: track, block: block, bluetoothService: bluetoothService)

            // ── Static threshold strip summary (last known state) ────────
            BlockThresholdStrip(session: session, block: block, track: track)

            // ── Main content ─────────────────────────────────────────────
            ScrollView {
                VStack(spacing: 20) {

                    // Result card
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: fs(52), weight: .bold))
                            .foregroundColor(AppColors.accentAmber)

                        Text("Keep Building")
                            .font(.system(size: fs(36), weight: .black, design: .rounded))
                            .foregroundColor(AppColors.primaryBlack)

                        Text("The next block builds on this one.")
                            .font(.system(size: fs(22), weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.border, lineWidth: 1))

                    // Accuracy comparison card
                    HStack(spacing: 0) {
                        // Achieved
                        VStack(spacing: 6) {
                            Text("\(achievedPercent)%")
                                .font(.system(size: fs(72), weight: .black, design: .rounded))
                                .foregroundColor(AppColors.primaryBlack)
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                            Text("YOUR SCORE")
                                .font(.system(size: fs(20), weight: .heavy, design: .rounded))
                                .foregroundColor(AppColors.textMuted)
                                .tracking(1.5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)

                        // Divider
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(width: 1)
                            .padding(.vertical, 16)

                        // Target
                        VStack(spacing: 6) {
                            Text("\(targetPercent)%")
                                .font(.system(size: fs(72), weight: .black, design: .rounded))
                                .foregroundColor(AppColors.accentGreen)
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                            Text("TARGET")
                                .font(.system(size: fs(20), weight: .heavy, design: .rounded))
                                .foregroundColor(AppColors.textMuted)
                                .tracking(1.5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.border, lineWidth: 1))

                    // Gap message
                    if gapPercent > 0 {
                        Text("\(gapPercent)% away from the threshold — another round closes that gap.")
                            .font(.system(size: fs(22), weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    // ── Action buttons ───────────────────────────────────
                    // Phase 4: hard gates lock "Continue anyway" until 3 failed attempts.
                    let isHardGate = evaluation.gateForce == .hard
                    let overrideEnabled = !isHardGate || evaluation.failedAttemptCount >= 3
                    let attemptsUntilOverride = max(0, 3 - evaluation.failedAttemptCount)

                    VStack(spacing: 12) {
                        // Repeat — primary action (large, green)
                        Button {
                            trainingViewModel.repeatBlock()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: fs(26), weight: .bold))
                                Text("Repeat This Block")
                                    .font(.system(size: fs(28), weight: .black, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(AppColors.accentGreen)
                            .cornerRadius(18)
                        }

                        // Continue anyway — secondary (outlined, smaller)
                        // Locked for hard gates until 3rd failed attempt
                        VStack(spacing: 6) {
                            Button {
                                if overrideEnabled { trainingViewModel.overrideAndContinue() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: overrideEnabled ? "arrow.right.circle" : "lock.fill")
                                        .font(.system(size: fs(22), weight: .semibold))
                                    Text("Continue Anyway")
                                        .font(.system(size: fs(22), weight: .bold, design: .rounded))
                                    if overrideEnabled {
                                        Text("(Override)")
                                            .font(.system(size: fs(18), weight: .regular, design: .rounded))
                                            .foregroundColor(AppColors.textMuted)
                                    }
                                }
                                .foregroundColor(overrideEnabled ? AppColors.primaryBlack : AppColors.textMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(18)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(overrideEnabled ? AppColors.border : AppColors.border.opacity(0.4),
                                                lineWidth: 1.5)
                                )
                                .opacity(overrideEnabled ? 1.0 : 0.6)
                            }
                            .disabled(!overrideEnabled)

                            if isHardGate && !overrideEnabled {
                                Text("Override unlocks after \(attemptsUntilOverride) more attempt\(attemptsUntilOverride == 1 ? "" : "s")")
                                    .font(.system(size: fs(18), weight: .medium, design: .rounded))
                                    .foregroundColor(AppColors.textMuted)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(AppColors.backgroundAlt.ignoresSafeArea())
    }
}

