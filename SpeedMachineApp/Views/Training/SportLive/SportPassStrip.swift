//
//  SportPassStrip.swift
//  SpeedMachine
//
//  The pass-progress strip at the top of the Sport live view.
//  Two columns of big stats, tach history bars, and pass-needed countdown bars.
//  Mirrors the pass-strip section of variant-b1-tach.jsx.
//

import SwiftUI

// MARK: - Strip config

enum SportPassStripConfig {
    /// Standard block: PUTTS LEFT / PUTTS NEEDED (zone pass threshold)
    case standard(totalPutts: Int, puttsTaken: Int, inZone: Int, passThreshold: Int)
    /// Gate test: same two-col layout but labelled for gate context
    case gateTest(totalPutts: Int, puttsTaken: Int, inZone: Int, passThreshold: Int)
    /// Make-in-row: PUTTS HIT (cumulative) / PUTTS REMAINING (goal − consecutive)
    case makeInRow(puttsHit: Int, consecutive: Int, goal: Int)
    /// Ladder: RUNG x/y + PUTTS HIT (mockup 10)
    case ladder(currentRung: Int, totalRungs: Int, puttsHit: Int)
    /// Exploration: single column PUTTS LEFT (countdown from totalPutts)
    case exploration(totalPutts: Int, puttsTaken: Int)
}

// MARK: - Main strip

struct SportPassStrip: View {
    let config: SportPassStripConfig
    let tokens: SportTokens
    var puttHistory: [PuttResult] = []
    var totalPutts: Int = 0
    var target: Int = 0
    var tolerance: Float = 0.5

    var body: some View {
        VStack(spacing: 0) {
            // Stat columns
            HStack(alignment: .bottom, spacing: 0) {
                switch config {
                case .standard(let total, let taken, let inZone, let threshold),
                     .gateTest(let total, let taken, let inZone, let threshold):
                    let isGate = {
                        if case .gateTest = config { return true }
                        return false
                    }()
                    statColumn(
                        label: "PUTTS\nLEFT",
                        value: max(0, total - taken),
                        color: tokens.fg
                    )
                    statColumn(
                        label: isGate ? "ZONE\nNEEDED" : "PUTTS\nNEEDED",
                        value: max(0, threshold - inZone),
                        color: tokens.fg
                    )

                case .makeInRow(let hit, let consecutive, let goal):
                    statColumn(label: "PUTTS\nHIT", value: hit, color: tokens.fg)
                    statColumn(label: "PUTTS\nREMAINING", value: max(0, goal - consecutive), color: tokens.fg)

                case .ladder(let rung, let total, let puttsHit):
                    rungColumn(rung: rung, total: total)
                    statColumn(label: "PUTTS\nHIT", value: puttsHit, color: tokens.fg)

                case .exploration(let total, let taken):
                    singleStatColumn(
                        label: "PUTTS\nLEFT",
                        value: "\(max(0, total - taken))",
                        color: tokens.fg
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 4)

            // Tach history bars (all configs except ladder & exploration single-col still get them)
            if case .ladder = config { } else if case .exploration = config { } else {
                TachBars(
                    history: puttHistory,
                    total: totalPutts,
                    target: target,
                    tolerance: tolerance,
                    tokens: tokens
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 4)

                // Pass-needed countdown bars
                if let (threshold, inZone) = passThresholdPair {
                    PassNeededBars(
                        passThreshold: threshold,
                        inZone: inZone,
                        totalPutts: totalPutts,
                        tokens: tokens
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 4)
                }
            }
        }
        .background(tokens.bg)
        .overlay(Rectangle().fill(tokens.subtle).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Helpers

    private var passThresholdPair: (Int, Int)? {
        switch config {
        case .standard(_, _, let inZone, let threshold):
            return (threshold, inZone)
        case .gateTest(_, _, let inZone, let threshold):
            return (threshold, inZone)
        case .makeInRow(_, let consecutive, let goal):
            return (goal, consecutive)
        default:
            return nil
        }
    }

    @ViewBuilder
    private func statColumn(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .center, spacing: 0) {
            Text(label)
                .font(.inter(fs(20), weight: .heavy))
                .foregroundColor(tokens.sub)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .tracking(fs(20) * 0.16)
            Text(String(format: "%02d", value))
                .font(.inter(fs(84)))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // RUNG x/y — big numerator, small grey denominator (mockup .val .denom)
    @ViewBuilder
    private func rungColumn(rung: Int, total: Int) -> some View {
        VStack(alignment: .center, spacing: 0) {
            Text("RUNG")
                .font(.inter(fs(20), weight: .heavy))
                .foregroundColor(tokens.sub)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .tracking(fs(20) * 0.16)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(rung)")
                    .font(.inter(fs(84)))
                    .foregroundColor(tokens.fg)
                    .monospacedDigit()
                Text(" / \(total)")
                    .font(.inter(fs(42), weight: .heavy))
                    .foregroundColor(tokens.sub)
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.4)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func singleStatColumn(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 0) {
            Text(label)
                .font(.inter(fs(20), weight: .heavy))
                .foregroundColor(tokens.sub)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .tracking(fs(20) * 0.16)
            Text(value)
                .font(.inter(fs(84)))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }
}

// MARK: - Tach Bars

struct TachBars: View {
    let history: [PuttResult]
    let total: Int
    let target: Int
    let tolerance: Float
    let tokens: SportTokens

    private let maxBarH: CGFloat = 40
    private let minBarH: CGFloat = 2
    private var visMax: Float { tolerance * 2.0 }    // e.g. 1.0 MPH when zone is ±0.5
    private var totalHeight: CGFloat { maxBarH * 2 } // 80pt

    var body: some View {
        GeometryReader { geo in
            let barCount = max(1, total)
            let totalGap = CGFloat(barCount - 1) * 2
            let barWidth = min(30, max(2, (geo.size.width - totalGap) / CGFloat(barCount)))

            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    let putt = i < history.count ? history[i] : nil

                    ZStack {
                        // Hairline through center of each slot
                        Rectangle()
                            .fill(tokens.subtle)
                            .frame(height: 1)

                        if let p = putt {
                            // p.difference = |roundedActual - target| — matches what is shown on screen
                            let isDeadOn = p.difference < 0.001

                            if isDeadOn {
                                // Gold 3D star replaces the tach bar for a perfect putt
                                let starSize: CGFloat = max(10, min(barWidth, 22))
                                Image(systemName: "star.fill")
                                    .font(.system(size: starSize, weight: .black))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1.0,  green: 0.90, blue: 0.20), // bright highlight
                                                Color(red: 0.95, green: 0.70, blue: 0.00), // warm gold
                                                Color(red: 0.72, green: 0.45, blue: 0.00)  // deep amber
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.0).opacity(0.45), radius: 3, x: 0, y: 0)
                                    .shadow(color: Color.black.opacity(0.30), radius: 2, x: 1, y: 1.5)
                            } else {
                                let dev = p.actualSpeed - p.targetSpeed
                                let clamped = max(-visMax, min(visMax, dev))
                                let ratio = CGFloat(abs(clamped) / visMax)
                                let barH = minBarH + ratio * (maxBarH - minBarH)
                                let color: Color = p.isInZone ? tokens.zone : tokens.miss
                                let isAbove = dev >= 0

                                // ZStack centers children at y=0 (center of container).
                                // Shift up by barH/2 → bottom edge on center line (above target).
                                // Shift down by barH/2 → top edge on center line (below target).
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color)
                                    .frame(width: barWidth, height: barH)
                                    .offset(y: isAbove ? -(barH / 2) : (barH / 2))
                            }
                        }
                    }
                    .frame(width: barWidth, height: totalHeight)
                    .clipped()
                }
            }
        }
        .frame(height: totalHeight)
    }
}

// MARK: - Pass Needed Bars

struct PassNeededBars: View {
    let passThreshold: Int
    let inZone: Int
    let totalPutts: Int
    let tokens: SportTokens

    var body: some View {
        GeometryReader { geo in
            let count = max(1, passThreshold)
            let totalGap = CGFloat(totalPutts - 1) * 2
            let barWidth = max(2, (geo.size.width - totalGap) / CGFloat(max(1, totalPutts)))

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ForEach(0..<count, id: \.self) { i in
                    let depleted = i < inZone
                    RoundedRectangle(cornerRadius: 3)
                        .fill(depleted ? tokens.subtle : tokens.zone)
                        .opacity(depleted ? 0.35 : 1)
                        .scaleEffect(y: depleted ? 0.2 : 1, anchor: .bottom)
                        .animation(.easeInOut(duration: 0.3), value: depleted)
                        .frame(width: barWidth, height: 20)
                    if i < count - 1 {
                        Spacer().frame(width: 2)
                    }
                }
            }
        }
        .frame(height: 20)
    }
}
