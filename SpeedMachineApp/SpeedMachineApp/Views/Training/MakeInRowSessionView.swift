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

    private var rowGoal: Int { block.consecutiveRequired ?? 5 }

    var body: some View {
        SportLiveContainer(
            session: session,
            block: block,
            track: track,
            stripConfig: .makeInRow(
                totalPutts: session.totalPutts,
                puttsTaken: session.currentPutt,
                consecutive: session.consecutiveSuccesses,
                goal: rowGoal
            ),
            headerIcon: .rec,
            bluetoothService: bluetoothService
        )
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
