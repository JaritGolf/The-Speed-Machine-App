//
//  MakeInRowSessionView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//
//  Make 5 in a Row Challenge UI (Day 7, Block 7B)
//  User hits 5 consecutive in-zone putts at 5 MPH to complete.
//

import SwiftUI
import UIKit

struct MakeInRowSessionView: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let track: TrainingTrack

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var showEndSessionAlert = false
    @Environment(\.isLandscapeOrientation) var isLandscape
    var lastPutt: PuttResult? { session.puttRecords.last }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SessionHeaderCompact(track: track, block: block, bluetoothService: bluetoothService)
            BlockThresholdStrip(session: session, block: block, track: track)

            if isLandscape {
                GeometryReader { geo in
                    HStack(spacing: 10) {
                        // Left: Consecutive hit indicator
                        ConsecutiveHitIndicator(consecutiveCount: session.consecutiveSuccesses)
                            .frame(width: geo.size.width * 0.35)

                        // Center: Current speed + last putt
                        VStack(spacing: 8) {
                            VStack(spacing: 0) {
                                Text("TARGET SPEED")
                                    .font(.system(size: fs(20), weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.textMuted).tracking(2)
                                Text("\(session.currentTargetSpeed)")
                                    .font(.system(size: fs(140), weight: .black, design: .rounded))
                                    .foregroundColor(AppColors.primaryBlack)
                                    .minimumScaleFactor(0.3).lineLimit(1)
                                Text("MPH")
                                    .font(.system(size: fs(24), weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.textMuted)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white).cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.border, lineWidth: 1))

                            if let lastPutt = lastPutt {
                                LastPuttCardLarge(lastPutt: lastPutt)
                            } else {
                                VStack(spacing: 4) {
                                    Text("--.-")
                                        .font(.system(size: fs(56), weight: .bold, design: .rounded))
                                        .foregroundColor(AppColors.textMuted)
                                }
                                .frame(maxWidth: .infinity, maxHeight: 120)
                                .background(Color.white).cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Right: Stats + end
                        VStack(spacing: 8) {
                            Spacer()
                            VStack(spacing: 12) {
                                SessionStatRowLarge(label: "Consecutive", value: "\(session.consecutiveSuccesses)/5")
                                Divider()
                                SessionStatRowLarge(label: "Putts", value: "\(session.currentPutt)")
                            }
                            .padding(16).background(Color.white).cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))

                            EndSessionButtonCompact(showEndSessionAlert: $showEndSessionAlert)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, max(6, geo.safeAreaInsets.bottom))
                    .padding(.leading, max(10, geo.safeAreaInsets.leading + 4))
                    .padding(.trailing, max(10, geo.safeAreaInsets.trailing + 4))
                }
                .ignoresSafeArea(edges: .horizontal)
            } else {
                // PORTRAIT
                VStack(spacing: 12) {
                    // Consecutive hit indicator — prominent
                    ConsecutiveHitIndicator(consecutiveCount: session.consecutiveSuccesses)
                        .frame(height: 180)
                        .padding(.horizontal, 20)

                    // Current speed
                    VStack(spacing: 0) {
                        Text("TARGET SPEED")
                            .font(.system(size: fs(24), weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textMuted).tracking(2)
                        Text("\(session.currentTargetSpeed)")
                            .font(.system(size: fs(160), weight: .black, design: .rounded))
                            .foregroundColor(AppColors.primaryBlack)
                            .minimumScaleFactor(0.3).lineLimit(1)
                        Text("MPH")
                            .font(.system(size: fs(28), weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white).cornerRadius(24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.border, lineWidth: 1))

                    // Last putt
                    if let lastPutt = lastPutt {
                        LastPuttCardLarge(lastPutt: lastPutt)
                    } else {
                        VStack(spacing: 4) {
                            Text("--.-")
                                .font(.system(size: fs(80), weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.textMuted)
                        }
                        .padding(.vertical, 16).frame(maxWidth: .infinity)
                        .background(Color.white).cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.border, lineWidth: 1))
                    }

                    // Stats
                    VStack(spacing: 12) {
                        SessionStatRowLarge(label: "Consecutive", value: "\(session.consecutiveSuccesses)/5")
                        Divider()
                        SessionStatRowLarge(label: "Putts", value: "\(session.currentPutt)")
                    }
                    .padding(16).background(Color.white).cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))

                    EndSessionButtonCompact(showEndSessionAlert: $showEndSessionAlert)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .padding(.top, 4)
            }
        }
        .alert("End Session?", isPresented: $showEndSessionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { trainingViewModel.endSession() }
        } message: {
            Text("Are you sure you want to end the session? Your progress will be saved.")
        }
    }
}

// MARK: - Consecutive Hit Indicator

struct ConsecutiveHitIndicator: View {
    let consecutiveCount: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("CONSECUTIVE HITS")
                .font(.system(size: fs(20), weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textMuted)
                .tracking(2)

            HStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { hitNumber in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(hitNumber < consecutiveCount ? AppColors.accentGreen : AppColors.border.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle().stroke(
                                    hitNumber < consecutiveCount ? AppColors.accentGreen : AppColors.border,
                                    lineWidth: 2
                                )
                            )

                        Text("\(hitNumber + 1)")
                            .font(.system(size: fs(18), weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.primaryBlack)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.border, lineWidth: 1))
    }
}
