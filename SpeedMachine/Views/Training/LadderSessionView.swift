//
//  LadderSessionView.swift
//  SpeedMachine
//
//  Elimination Ladder Challenge UI (Day 7, Block 7C)
//  Landscape: Target Speed | Actual Speed | Putts Hit + End Session, rung track at bottom
//  Portrait:  Vertical rung ladder card on left, proportionally sized panels on right
//

import SwiftUI
import UIKit

// kLabelSize is computed per-device so it scales on iPad
private var kLabelSize: CGFloat { fs(40) }

struct LadderSessionView: View {
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
            SessionHeaderCompact(track: track, block: block, bluetoothService: bluetoothService)
            BlockThresholdStrip(session: session, block: block, track: track)

            if isLandscape {
                LadderLandscapeLayout(
                    session: session,
                    lastPutt: lastPutt,
                    showEndSessionAlert: $showEndSessionAlert
                )
            } else {
                LadderPortraitLayout(
                    session: session,
                    lastPutt: lastPutt,
                    showEndSessionAlert: $showEndSessionAlert
                )
            }
        }
        .alert("End Session?", isPresented: $showEndSessionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { trainingViewModel.endSession() }
        } message: {
            Text("Are you sure you want to end the ladder? Your progress will be saved.")
        }
    }
}

// MARK: - Landscape Layout

private struct LadderLandscapeLayout: View {
    @ObservedObject var session: SessionProgress
    let lastPutt: PuttResult?
    @Binding var showEndSessionAlert: Bool

    var body: some View {
        GeometryReader { geo in
            let insetLeading  = max(12, geo.safeAreaInsets.leading + 4)
            let insetTrailing = max(12, geo.safeAreaInsets.trailing + 4)
            let insetBottom   = max(8,  geo.safeAreaInsets.bottom)
            let gap:    CGFloat = 8
            let rungH:  CGFloat = isIPad ? 77 : 55
            let rightW: CGFloat = max(isIPad ? 196 : 140, geo.size.width * 0.20)

            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    LadderSpeedPanel(
                        label: "Target Speed",
                        valueText: "\(session.getCurrentLadderSpeed())",
                        valueColor: AppColors.primaryBlack
                    )
                    LadderActualSpeedPanel(lastPutt: lastPutt)
                    VStack(spacing: gap) {
                        LadderPuttsHitPanel(count: session.currentPutt)
                        Spacer()
                        EndSessionButtonCompact(showEndSessionAlert: $showEndSessionAlert)
                    }
                    .frame(width: rightW)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ── Rung blocks — same block style as portrait, laid out horizontally
                HorizontalRungBlocks(
                    ladderSpeeds: session.ladderSpeeds,
                    currentRung: session.currentRung
                )
                .frame(height: rungH)
                .padding(.vertical, 5)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
            }
            .padding(.top, 6)
            .padding(.bottom, insetBottom)
            .padding(.leading, insetLeading)
            .padding(.trailing, insetTrailing)
        }
        .ignoresSafeArea(edges: .horizontal)
    }
}

// MARK: - Portrait Layout

private struct LadderPortraitLayout: View {
    @ObservedObject var session: SessionProgress
    let lastPutt: PuttResult?
    @Binding var showEndSessionAlert: Bool

    var body: some View {
        GeometryReader { geo in
            // All layout constants local — avoids self-capture issues inside closure
            let endBtnH: CGFloat = isIPad ? 90 : 64
            let puttsH:  CGFloat = isIPad ? 210 : 150
            let hPad:    CGFloat = 12
            let vPad:    CGFloat = 8
            let gap:     CGFloat = 8
            let ladderW: CGFloat = isIPad ? 90 : 65

            let totalV = max(0, geo.size.height - vPad * 2)
            let fixedH = endBtnH + puttsH + gap * 3
            let speedH = max(80, (totalV - fixedH) / 2)

            HStack(alignment: .top, spacing: gap) {

                // ── Rung ladder card ────────────────────────────────────
                VerticalRungLadder(
                    ladderSpeeds: session.ladderSpeeds,
                    currentRung: session.currentRung
                )
                .frame(width: ladderW, height: totalV)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))

                // ── Right panels ────────────────────────────────────────
                VStack(spacing: gap) {
                    LadderSpeedPanel(
                        label: "Target Speed",
                        valueText: "\(session.getCurrentLadderSpeed())",
                        valueColor: AppColors.primaryBlack
                    )
                    .frame(height: speedH)

                    LadderActualSpeedPanel(lastPutt: lastPutt)
                        .frame(height: speedH)

                    LadderPuttsHitPanel(count: session.currentPutt)
                        .frame(height: puttsH)

                    EndSessionButtonCompact(showEndSessionAlert: $showEndSessionAlert)
                        .frame(height: endBtnH)
                }
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Speed Panels

/// Target / any fixed-speed panel: big number fills the card
private struct LadderSpeedPanel: View {
    let label: String
    let valueText: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: kLabelSize, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textMuted)
                .padding(.top, 12)

            Spacer(minLength: 0)

            Text(valueText)
                .font(.system(size: fs(200), weight: .black, design: .rounded))
                .foregroundColor(valueColor)
                .minimumScaleFactor(0.1)
                .lineLimit(1)
                .padding(.horizontal, 8)

            Text("MPH")
                .font(.system(size: kLabelSize, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textMuted)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.border, lineWidth: 1))
    }
}

/// Actual speed panel: shows last putt result or a clean waiting state
private struct LadderActualSpeedPanel: View {
    let lastPutt: PuttResult?

    var speedColor: Color {
        guard let p = lastPutt else { return AppColors.border }
        return p.isInZone ? AppColors.accentGreen : AppColors.error
    }

    var borderColor: Color {
        guard let p = lastPutt else { return AppColors.border }
        return p.isInZone ? AppColors.accentGreen.opacity(0.4) : AppColors.error.opacity(0.3)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Actual Speed")
                .font(.system(size: kLabelSize, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textMuted)
                .padding(.top, 12)

            Spacer(minLength: 0)

            if let putt = lastPutt {
                Text(putt.actualSpeed.toSpeedString())
                    .font(.system(size: fs(160), weight: .black, design: .rounded))
                    .foregroundColor(speedColor)
                    .minimumScaleFactor(0.1)
                    .lineLimit(1)
                    .padding(.horizontal, 8)

                Image(systemName: putt.isInZone ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: kLabelSize))
                    .foregroundColor(speedColor)
            } else {
                Text("—")
                    .font(.system(size: 160, weight: .black, design: .default))
                    .foregroundColor(AppColors.border)
                    .minimumScaleFactor(0.1)
                    .lineLimit(1)

                Text("Waiting for putt")
                    .font(.system(size: kLabelSize, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textMuted)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: lastPutt != nil ? 2 : 1)
        )
    }
}

/// Putts Hit: large count stacked above label
private struct LadderPuttsHitPanel: View {
    let count: Int

    var body: some View {
        VStack(spacing: 2) {
            Spacer(minLength: 0)
            Text("\(count)")
                .font(.system(size: fs(80), weight: .black, design: .rounded))
                .foregroundColor(AppColors.primaryBlack)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("Putts Hit")
                .font(.system(size: kLabelSize, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textMuted)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
    }
}

// MARK: - Horizontal Rung Blocks (Landscape bottom)
// Uses the same LadderRungBlock style as the portrait vertical ladder

struct HorizontalRungBlocks: View {
    let ladderSpeeds: [Int]
    let currentRung: Int

    private let connW: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let count     = ladderSpeeds.count
            let totalConn = CGFloat(max(0, count - 1)) * connW
            let blockW    = count > 0 ? max(40, (max(0, geo.size.width) - totalConn - 16) / CGFloat(count)) : 60
            let blockH    = max(36, geo.size.height)

            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { idx in
                    LadderRungBlock(
                        speed: ladderSpeeds[idx],
                        state: idx < currentRung ? .completed : (idx == currentRung ? .current : .upcoming),
                        blockH: blockH,
                        connH: 0,
                        isLastRung: true   // suppress vertical connector — we draw horizontal ones
                    )
                    .frame(width: blockW)

                    if idx < count - 1 {
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(width: connW, height: 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Vertical Rung Ladder (Portrait left card)

struct VerticalRungLadder: View {
    let ladderSpeeds: [Int]
    let currentRung: Int

    // Block height caps — prevents rungs from being absurdly tall with few rungs
    // or unreadably short with many rungs
    private let maxBlockH: CGFloat = 200
    private let minBlockH: CGFloat = 36
    private let connH:     CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let count     = ladderSpeeds.count
            let totalConn = CGFloat(max(0, count - 1)) * connH
            let rawH      = count > 0 ? (max(0, geo.size.height) - totalConn - 16) / CGFloat(count) : minBlockH
            let blockH    = min(maxBlockH, max(minBlockH, rawH))
            let usedH     = blockH * CGFloat(count) + totalConn
            let extraPad  = max(0, geo.size.height - 16 - usedH) / 2

            VStack(spacing: 0) {
                Spacer().frame(height: max(0, extraPad + 8))

                ForEach((0..<count).reversed(), id: \.self) { idx in
                    LadderRungBlock(
                        speed: ladderSpeeds[idx],
                        state: idx < currentRung ? .completed : (idx == currentRung ? .current : .upcoming),
                        blockH: blockH,
                        connH: connH,
                        isLastRung: idx == 0
                    )
                }

                Spacer().frame(height: max(0, extraPad + 8))
            }
        }
    }

}

// MARK: - Rung Block (sub-struct avoids @ViewBuilder type-inference issues)

private enum RungState { case completed, current, upcoming }

private struct LadderRungBlock: View {
    let speed:      Int
    let state:      RungState
    let blockH:     CGFloat
    let connH:      CGFloat
    let isLastRung: Bool

    private var numSize:  CGFloat { min(28, max(14, blockH * 0.32)) }
    private var unitSize: CGFloat { min(13, max(9,  blockH * 0.15)) }
    private var iconSize: CGFloat { min(13, max(8,  blockH * 0.15)) }

    private var fill:   Color {
        switch state {
        case .completed: return AppColors.accentGreen
        case .current:   return AppColors.accentGreen.opacity(0.07)
        case .upcoming:  return Color(hex: "f5f5f5")
        }
    }
    private var stroke: Color {
        switch state {
        case .completed: return AppColors.accentGreen
        case .current:   return AppColors.accentGreen
        case .upcoming:  return AppColors.border
        }
    }
    private var numColor: Color {
        switch state {
        case .completed: return .white
        case .current:   return AppColors.accentGreen
        case .upcoming:  return AppColors.textMuted
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(fill)
                RoundedRectangle(cornerRadius: 6)
                    .stroke(stroke, lineWidth: state == .current ? 2 : 1)

                VStack(spacing: 1) {
                    Group {
                        if state == .completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: iconSize, weight: .bold))
                                .foregroundColor(.white)
                        } else if state == .current {
                            Image(systemName: "arrow.right")
                                .font(.system(size: iconSize, weight: .bold))
                                .foregroundColor(AppColors.accentGreen)
                        } else {
                            Color.clear.frame(width: 1, height: iconSize + 2)
                        }
                    }

                    Text("\(speed)")
                        .font(.system(size: numSize, weight: .black, design: .rounded))
                        .foregroundColor(numColor)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text("MPH")
                        .font(.system(size: unitSize, weight: .semibold, design: .rounded))
                        .foregroundColor(numColor.opacity(0.75))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: blockH)
            .padding(.horizontal, 6)

            // Connector line below every rung except the bottom one
            if !isLastRung {
                Rectangle()
                    .fill(AppColors.border)
                    .frame(width: 2, height: connH)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Legacy alias kept for any existing references
struct LadderRungIndicator: View {
    let currentRung: Int

    var body: some View {
        VerticalRungLadder(
            ladderSpeeds: Array(3...7),
            currentRung: currentRung
        )
    }
}
