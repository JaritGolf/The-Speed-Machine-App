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
    /// Make-in-row: PUTTS TAKEN (running total of all attempts) / PUTTS REMAINING (goal − consecutive)
    case makeInRow(puttsTaken: Int, consecutive: Int, goal: Int)
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
    /// When true (multi-speed standard / gate-test blocks), the tachs become a
    /// fixed-width, finger-scrollable strip with a target-speed label per putt.
    var isMultiSpeed: Bool = false

    /// Labeled scrolling tachs only for multi-speed standard & gate-test blocks.
    /// Make-in-row and single-speed blocks keep the existing compress/auto-scroll behavior.
    private var showSpeedLabels: Bool {
        switch config {
        case .standard, .gateTest: return isMultiSpeed
        default: return false
        }
    }

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

                case .makeInRow(let taken, let consecutive, let goal):
                    statColumn(label: "PUTTS\nTAKEN", value: taken, color: tokens.fg)
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
                    tokens: tokens,
                    labeled: showSpeedLabels
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
        .overlay(alignment: .bottom) {
            // Make-in-row drops the bottom hairline (it follows the tachs directly).
            if case .makeInRow = config {
                EmptyView()
            } else {
                Rectangle().fill(tokens.subtle).frame(height: 1)
            }
        }
    }

    // MARK: - Helpers

    private var passThresholdPair: (Int, Int)? {
        switch config {
        case .standard(_, _, let inZone, let threshold):
            return (threshold, inZone)
        case .gateTest(_, _, let inZone, let threshold):
            return (threshold, inZone)
        // Make-in-row intentionally omits the pass-needed countdown bars — they are
        // redundant with the PUTTS REMAINING number and the CONSECUTIVE HITS dots.
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
    /// Multi-speed blocks: fixed-width, finger-scrollable strip with a target-speed
    /// label per putt. Default false keeps the original compress / auto-scroll tachs.
    var labeled: Bool = false

    private let maxBarH: CGFloat = 40
    private let minBarH: CGFloat = 2
    private var visMax: Float { tolerance * 2.0 }    // e.g. 1.0 MPH when zone is ±0.5
    private var totalHeight: CGFloat { maxBarH * 2 } // 80pt

    // Labeled mode: fixed slot wide enough for a 2-digit MPH label at 5–6 ft.
    private let gap: CGFloat = 2
    private var labeledSlotW: CGFloat { fs(34) }

    // Manual drag-to-review offset (positive = pulled back toward older putts).
    @State private var dragOffset: CGFloat = 0
    @GestureState private var liveDrag: CGFloat = 0

    var body: some View {
        if labeled {
            labeledBody
        } else {
            compactBody
        }
    }

    // MARK: - Original compress / auto-scroll tachs (single-speed & make-in-row)

    private var compactBody: some View {
        GeometryReader { geo in
            let barCount = max(1, total)
            let totalGap = CGFloat(barCount - 1) * 2
            let barWidth = min(30, max(2, (geo.size.width - totalGap) / CGFloat(barCount)))
            // Once putts exceed the visible slots (make-in-row has no putt cap), keep the
            // bar width fixed and scroll the whole strip left so the oldest bar slides off
            // and the newest enters on the right. Below capacity scrollX == 0 → unchanged.
            let slotCount = max(barCount, history.count)
            let scrollX = max(0, CGFloat(history.count - barCount)) * (barWidth + 2)

            HStack(spacing: 2) {
                ForEach(0..<slotCount, id: \.self) { i in
                    let putt = i < history.count ? history[i] : nil

                    ZStack {
                        // Hairline through center of each slot
                        Rectangle()
                            .fill(tokens.subtle)
                            .frame(height: 1)

                        if let p = putt {
                            tachMark(for: p, slotWidth: barWidth)
                        }
                    }
                    .frame(width: barWidth, height: totalHeight)
                    .clipped()
                }
            }
            .offset(x: -scrollX)
            .frame(width: geo.size.width, alignment: .leading)
            .clipped()
            .animation(.easeInOut(duration: 0.3), value: history.count)
        }
        .frame(height: totalHeight)
    }

    // MARK: - Labeled, fixed-width, finger-scrollable tachs (multi-speed)

    private var labeledBody: some View {
        GeometryReader { geo in
            let slotStride = labeledSlotW + gap
            // Fill the viewport with slots, then grow & scroll once putts exceed it.
            let visibleSlots = max(1, Int(floor((geo.size.width + gap) / slotStride)))
            let slotCount = max(visibleSlots, history.count)
            let contentW = CGFloat(slotCount) * slotStride - gap
            // Auto-scroll so the newest putt sits at the right edge.
            let autoScrollX = max(0, contentW - geo.size.width)
            // Drag pulls older putts back into view; clamp within [live, oldest].
            let clampedDrag = min(autoScrollX, max(0, dragOffset + liveDrag))
            let offsetX = -(autoScrollX - clampedDrag)

            HStack(spacing: gap) {
                ForEach(0..<slotCount, id: \.self) { i in
                    let putt = i < history.count ? history[i] : nil

                    ZStack {
                        // Hairline through center of each slot
                        Rectangle()
                            .fill(tokens.subtle)
                            .frame(height: 1)

                        if let p = putt {
                            tachMark(for: p, slotWidth: labeledSlotW)

                            // Target speed for this putt, sitting on the center line over the bar.
                            Text("\(Int(p.targetSpeed.rounded()))")
                                .font(.inter(fs(20), weight: .heavy))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .foregroundColor(tokens.fg)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(tokens.bg)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(tokens.subtle, lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .frame(width: labeledSlotW, height: totalHeight)
                    .clipped()
                }
            }
            .frame(width: contentW, alignment: .leading)
            .offset(x: offsetX)
            .frame(width: geo.size.width, alignment: .leading)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .updating($liveDrag) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        dragOffset = min(autoScrollX, max(0, dragOffset + value.translation.width))
                    }
            )
            .animation(.easeInOut(duration: 0.3), value: history.count)
        }
        .frame(height: totalHeight)
        // New putt → snap back to the newest tach so the latest result is never missed.
        .onChange(of: history.count) { _, _ in
            withAnimation(.easeInOut(duration: 0.3)) { dragOffset = 0 }
        }
    }

    // MARK: - Shared tach mark (bar or gold dead-on star)

    @ViewBuilder
    private func tachMark(for p: PuttResult, slotWidth: CGFloat) -> some View {
        // p.difference = |roundedActual - target| — matches what is shown on screen
        let isDeadOn = p.difference < 0.001

        if isDeadOn {
            // Gold 3D star replaces the tach bar for a perfect putt
            let starSize: CGFloat = max(10, min(slotWidth, 22))
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
                .frame(width: slotWidth, height: barH)
                .offset(y: isAbove ? -(barH / 2) : (barH / 2))
        }
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
