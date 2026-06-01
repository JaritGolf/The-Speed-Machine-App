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
private var kLabelSize: CGFloat { fs(28) }

struct LadderSessionView: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let track: TrainingTrack

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var showEndSessionAlert = false
    @Environment(\.isLandscapeOrientation) var isLandscape

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme

    private var theme: LiveViewTheme { LiveViewTheme(rawValue: themeRaw) ?? .light }
    private var isDark: Bool { theme.resolvedDark(scheme: colorScheme) }
    private var tokens: SportTokens { SportTokens.make(dark: isDark) }

    var lastPutt: PuttResult? { session.puttRecords.last }
    var totalRungs: Int { session.ladderSpeeds.count }
    var currentRung: Int { session.currentRung + 1 }

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                SportRecHeader(
                    track: track,
                    block: block,
                    tokens: tokens,
                    icon: .rec,
                    isConnected: bluetoothService.isConnected
                )

                // Single-col RUNG strip
                SportPassStrip(
                    config: .ladder(currentRung: currentRung, totalRungs: totalRungs),
                    tokens: tokens,
                    puttHistory: session.puttRecords,
                    totalPutts: session.totalPutts,
                    target: session.getCurrentLadderSpeed(),
                    tolerance: 0.5
                )

                // Rung-specific speed panels
                if isLandscape {
                    LadderLandscapeLayout(
                        session: session,
                        lastPutt: lastPutt,
                        tokens: tokens,
                        showEndSessionAlert: $showEndSessionAlert
                    )
                } else {
                    LadderPortraitLayout(
                        session: session,
                        lastPutt: lastPutt,
                        tokens: tokens,
                        showEndSessionAlert: $showEndSessionAlert
                    )
                }
            }

            // Edge flash
            SportEdgeFlash(
                lastPuttID: session.puttRecords.count,
                inZone: session.puttRecords.last?.isInZone
            )
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
    let tokens: SportTokens
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
                        label: "TARGET",
                        valueText: "\(session.getCurrentLadderSpeed())",
                        tokens: tokens
                    )
                    LadderActualSpeedPanel(lastPutt: lastPutt, tokens: tokens)
                    VStack(spacing: gap) {
                        LadderPuttsHitPanel(count: session.currentPutt, tokens: tokens)
                        Spacer()
                        SportEndButton(tokens: tokens, showAlert: $showEndSessionAlert)
                    }
                    .frame(width: rightW)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HorizontalRungBlocks(
                    ladderSpeeds: session.ladderSpeeds,
                    currentRung: session.currentRung,
                    tokens: tokens
                )
                .frame(height: rungH)
                .padding(.vertical, 5)
                .background(tokens.surface)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(tokens.subtle, lineWidth: 1))
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
    let tokens: SportTokens
    @Binding var showEndSessionAlert: Bool

    var body: some View {
        GeometryReader { geo in
            let endBtnH: CGFloat = isIPad ? 70 : 52
            let puttsH:  CGFloat = isIPad ? 180 : 130
            let hPad:    CGFloat = 12
            let vPad:    CGFloat = 8
            let gap:     CGFloat = 8
            let ladderW: CGFloat = isIPad ? 90 : 65

            let totalV = max(0, geo.size.height - vPad * 2)
            let fixedH = endBtnH + puttsH + gap * 3
            let speedH = max(80, (totalV - fixedH) / 2)

            HStack(alignment: .top, spacing: gap) {
                // Rung ladder card
                VerticalRungLadder(
                    ladderSpeeds: session.ladderSpeeds,
                    currentRung: session.currentRung,
                    tokens: tokens
                )
                .frame(width: ladderW, height: totalV)
                .background(tokens.surface)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(tokens.subtle, lineWidth: 1))

                // Right panels
                VStack(spacing: gap) {
                    LadderSpeedPanel(
                        label: "TARGET",
                        valueText: "\(session.getCurrentLadderSpeed())",
                        tokens: tokens
                    )
                    .frame(height: speedH)

                    LadderActualSpeedPanel(lastPutt: lastPutt, tokens: tokens)
                        .frame(height: speedH)

                    LadderPuttsHitPanel(count: session.currentPutt, tokens: tokens)
                        .frame(height: puttsH)

                    SportEndButton(tokens: tokens, showAlert: $showEndSessionAlert)
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

private struct LadderSpeedPanel: View {
    let label: String
    let valueText: String
    let tokens: SportTokens

    var body: some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.inter(kLabelSize, weight: .semibold))
                .foregroundColor(tokens.sub)
                .tracking(3)
                .padding(.top, 12)

            Spacer(minLength: 0)

            Text(valueText)
                .font(.inter(fs(180)))
                .foregroundColor(tokens.fg)
                .minimumScaleFactor(0.1)
                .lineLimit(1)
                .monospacedDigit()
                .padding(.horizontal, 8)

            Text("MPH")
                .font(.inter(kLabelSize, weight: .semibold))
                .foregroundColor(tokens.sub)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tokens.surface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(tokens.subtle, lineWidth: 1))
    }
}

private struct LadderActualSpeedPanel: View {
    let lastPutt: PuttResult?
    let tokens: SportTokens

    var speedColor: Color {
        guard let p = lastPutt else { return tokens.subtle }
        return p.isInZone ? tokens.zone : tokens.miss
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("ACTUAL")
                .font(.inter(kLabelSize, weight: .semibold))
                .foregroundColor(tokens.sub)
                .tracking(3)
                .padding(.top, 12)

            Spacer(minLength: 0)

            if let putt = lastPutt {
                Text(putt.actualSpeed.toSpeedString())
                    .font(.inter(fs(140)))
                    .foregroundColor(speedColor)
                    .minimumScaleFactor(0.1)
                    .lineLimit(1)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .sportPopIn(trigger: Int(putt.actualSpeed * 10))

                Image(systemName: putt.isInZone ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: kLabelSize))
                    .foregroundColor(speedColor)
            } else {
                Text("— —")
                    .font(.inter(fs(100)))
                    .foregroundColor(tokens.sub)
                    .minimumScaleFactor(0.1)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tokens.surface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(lastPutt != nil ? speedColor.opacity(0.5) : tokens.subtle, lineWidth: lastPutt != nil ? 2 : 1)
        )
    }
}

private struct LadderPuttsHitPanel: View {
    let count: Int
    let tokens: SportTokens

    var body: some View {
        VStack(spacing: 2) {
            Spacer(minLength: 0)
            Text("\(count)")
                .font(.inter(fs(72)))
                .foregroundColor(tokens.fg)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .monospacedDigit()
            Text("PUTTS HIT")
                .font(.inter(kLabelSize, weight: .semibold))
                .foregroundColor(tokens.sub)
                .tracking(2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .background(tokens.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(tokens.subtle, lineWidth: 1))
    }
}

// MARK: - Horizontal Rung Blocks (Landscape bottom)

struct HorizontalRungBlocks: View {
    let ladderSpeeds: [Int]
    let currentRung: Int
    var tokens: SportTokens = SportTokens.make(dark: true)

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
                        isLastRung: true,
                        tokens: tokens
                    )
                    .frame(width: blockW)

                    if idx < count - 1 {
                        Rectangle()
                            .fill(tokens.subtle)
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
    var tokens: SportTokens = SportTokens.make(dark: true)

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
                        isLastRung: idx == 0,
                        tokens: tokens
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
    var tokens:     SportTokens = SportTokens.make(dark: true)

    private var numSize:  CGFloat { min(28, max(14, blockH * 0.32)) }
    private var unitSize: CGFloat { min(13, max(9,  blockH * 0.15)) }
    private var iconSize: CGFloat { min(13, max(8,  blockH * 0.15)) }

    private var fill: Color {
        switch state {
        case .completed: return tokens.zone
        case .current:   return tokens.zone.opacity(0.12)
        case .upcoming:  return tokens.surface
        }
    }
    private var stroke: Color {
        switch state {
        case .completed: return tokens.zone
        case .current:   return tokens.zone
        case .upcoming:  return tokens.subtle
        }
    }
    private var numColor: Color {
        switch state {
        case .completed: return .white
        case .current:   return tokens.zone
        case .upcoming:  return tokens.sub
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
                                .foregroundColor(tokens.zone)
                        } else {
                            Color.clear.frame(width: 1, height: iconSize + 2)
                        }
                    }

                    Text("\(speed)")
                        .font(.inter(numSize))
                        .foregroundColor(numColor)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text("MPH")
                        .font(.inter(unitSize, weight: .semibold))
                        .foregroundColor(numColor.opacity(0.75))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: blockH)
            .padding(.horizontal, 6)

            if !isLastRung {
                Rectangle()
                    .fill(tokens.subtle)
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

