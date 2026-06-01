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
    /// Make-in-row: PUTTS LEFT / TO GO (threshold − consecutive)
    case makeInRow(totalPutts: Int, puttsTaken: Int, consecutive: Int, goal: Int)
    /// Ladder: single column RUNG
    case ladder(currentRung: Int, totalRungs: Int)
    /// Exploration: single column PUTTS TAKEN
    case exploration(puttsTaken: Int)
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

                case .makeInRow(let total, let taken, let consecutive, let goal):
                    statColumn(label: "PUTTS\nLEFT", value: max(0, total - taken), color: tokens.fg)
                    statColumn(label: "TO\nGO", value: max(0, goal - consecutive), color: tokens.fg)

                case .ladder(let rung, let total):
                    singleStatColumn(label: "RUNG", value: "\(rung)/\(total)", color: tokens.fg)

                case .exploration(let taken):
                    singleStatColumn(label: "PUTTS\nTAKEN", value: "\(taken)", color: tokens.fg)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 8)

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
                    .padding(.bottom, 8)
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
        case .makeInRow(_, _, let consecutive, let goal):
            return (goal, consecutive)
        default:
            return nil
        }
    }

    @ViewBuilder
    private func statColumn(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .center, spacing: 0) {
            Text(label)
                .font(.inter(fs(20)))
                .foregroundColor(tokens.sub)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .tracking(4)
            Text("\(value)")
                .font(.inter(fs(100)))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func singleStatColumn(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 0) {
            Text(label)
                .font(.inter(fs(22)))
                .foregroundColor(tokens.sub)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .tracking(4)
            Text(value)
                .font(.inter(fs(100)))
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

    private let visMax: Float = 2.5

    var body: some View {
        GeometryReader { geo in
            let barCount = max(1, total)
            let totalGap = CGFloat(barCount - 1) * 2
            let barWidth = max(2, (geo.size.width - totalGap) / CGFloat(barCount))

            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    let putt = i < history.count ? history[i] : nil
                    let barH: CGFloat = {
                        guard let p = putt else { return 4 }
                        let dev = max(-visMax, min(visMax, p.actualSpeed - Float(target)))
                        return 4 + CGFloat(abs(dev) / visMax) * 16
                    }()
                    let color: Color = {
                        guard let p = putt else { return tokens.subtle }
                        return p.isInZone ? tokens.zone : tokens.miss
                    }()

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(color)
                            .frame(width: barWidth, height: barH)
                    }
                    .frame(width: barWidth, height: 20)
                }
            }
        }
        .frame(height: 20)
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
                    RoundedRectangle(cornerRadius: 1.5)
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
