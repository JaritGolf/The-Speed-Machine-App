//
//  SportHeroCard.swift
//  SpeedMachine
//
//  Chromeless live target (mockup `.live-target` + `.last-putt`):
//    centered giant target number + "MPH | TARGET" row, then a hairline-topped
//    LAST PUTT section (speed + delta). No card, no ladder, no hit-rate.
//
//  Putt animation (preserved): on a new putt the actual speed is shown giant in
//  zone/miss colour for 3 s (.showing), then the number glides via
//  matchedGeometryEffect down into the LAST PUTT readout (.settled).
//

import SwiftUI

// MARK: - Display phase

private enum HeroPuttPhase: Equatable {
    case idle
    case showing
    case settled
}

// MARK: - Hero (chromeless target + last putt)

struct SportHeroCard<Accessory: View, Middle: View>: View {
    @ObservedObject var session: SessionProgress
    let tokens: SportTokens
    let tolerance: Float

    /// Overrides the displayed TARGET number. nil → `session.currentTargetSpeed`
    /// (ladder passes its current rung speed, where currentTargetSpeed is 0).
    var targetSpeed: Int? = nil
    /// Right-hand label in the unit row (e.g. "TARGET", "DON'T BREAK").
    var targetLabel: String = "TARGET"
    /// Colour of `targetLabel`. nil → `tokens.sub`.
    var targetLabelColor: Color? = nil
    /// Label above the LAST PUTT readout.
    var lastPuttLabel: String = "LAST PUTT"
    /// Multiplier on the idle/settled TARGET number font (make-in-row enlarges it
    /// to fill the space freed by dropping the pass-needed bars).
    var targetNumberScale: CGFloat = 1.0
    /// Optional accessory placed to the LEFT of the centre number (ladder graphic).
    let leftAccessory: Accessory
    /// Optional content placed BETWEEN the centre number and the LAST PUTT section
    /// (make-in-row streak dots).
    let middle: Middle

    @Namespace private var heroNS
    @State private var phase: HeroPuttPhase = .idle
    @State private var capturedPutt: PuttResult? = nil
    @State private var chipVisible = false
    @State private var animTask: Task<Void, Never>? = nil

    private var displayTarget: Int { targetSpeed ?? session.currentTargetSpeed }

    // Designated init — both slots supplied.
    init(session: SessionProgress, tokens: SportTokens, tolerance: Float,
         targetSpeed: Int? = nil, targetLabel: String = "TARGET",
         targetLabelColor: Color? = nil, lastPuttLabel: String = "LAST PUTT",
         targetNumberScale: CGFloat = 1.0,
         @ViewBuilder leftAccessory: () -> Accessory,
         @ViewBuilder middle: () -> Middle) {
        self.session = session
        self.tokens = tokens
        self.tolerance = tolerance
        self.targetSpeed = targetSpeed
        self.targetLabel = targetLabel
        self.targetLabelColor = targetLabelColor
        self.lastPuttLabel = lastPuttLabel
        self.targetNumberScale = targetNumberScale
        self.leftAccessory = leftAccessory()
        self.middle = middle()
    }

    // MARK: Animation trigger

    private func onNewPutt(_ putt: PuttResult) {
        animTask?.cancel()
        chipVisible = false
        capturedPutt = putt
        phase = .showing

        animTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    phase = .settled
                }
            }
            try? await Task.sleep(nanoseconds: 620_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    chipVisible = true
                }
            }
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                leftAccessory
                centerNumber
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 28)
            }
            Spacer(minLength: 0)
            middle
            lastPuttSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tokens.bg)
        .onChange(of: session.puttRecords.count) { _, count in
            guard count > 0, let p = session.puttRecords.last else { return }
            onNewPutt(p)
        }
    }

    // MARK: - Centre number

    @ViewBuilder
    private var centerNumber: some View {
        ZStack {
            // TARGET (idle + settled)
            let tStr = "\(displayTarget)"
            let tFont: CGFloat = (tStr.count >= 2 ? fs(150) : fs(200)) * targetNumberScale
            VStack(spacing: fs(8)) {
                Text(tStr)
                    .font(.inter(tFont))
                    .foregroundColor(tokens.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .monospacedDigit()
                unitRow(label: targetLabel, unitColor: tokens.fg)
            }
            .opacity(phase == .showing ? 0 : 1)

            // PUTT (showing; number glides to readout on settle)
            if let p = capturedPutt, phase == .showing {
                let pStr = String(format: "%.1f", p.actualSpeed)
                let pFont: CGFloat = pStr.count >= 4 ? fs(170) : fs(200)
                let col: Color = p.isInZone ? tokens.zone : tokens.miss
                VStack(spacing: fs(8)) {
                    Text(pStr)
                        .font(.inter(pFont))
                        .foregroundColor(col)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .monospacedDigit()
                        .matchedGeometryEffect(id: "puttValue", in: heroNS)
                    Text("MPH")
                        .font(.inter(fs(24), weight: .heavy))
                        .foregroundColor(tokens.sub)
                        .tracking(fs(24) * 0.06)
                }
                .sportPopIn(trigger: session.puttRecords.count)
            }
        }
    }

    // "MPH | TARGET" row (mockup .unit-row)
    @ViewBuilder
    private func unitRow(label: String, unitColor: Color) -> some View {
        HStack(spacing: 14) {
            Text("MPH")
                .font(.inter(fs(24), weight: .heavy))
                .foregroundColor(unitColor)
                .tracking(fs(24) * 0.06)
            Rectangle()
                .fill(tokens.subtle)
                .frame(width: 1, height: fs(20))
            Text(label)
                .font(.inter(fs(24), weight: .heavy))
                .foregroundColor(targetLabelColor ?? tokens.sub)
                .tracking(fs(24) * 0.22)
        }
    }

    // MARK: - Last putt section (mockup .last-putt)

    private var resultColor: Color {
        guard let p = capturedPutt else { return tokens.sub }
        return p.isInZone ? tokens.zone : tokens.miss
    }

    private var deltaString: String {
        guard let p = capturedPutt else { return "" }
        let d = p.actualSpeed - Float(p.targetSpeed)
        let sign = d > 0 ? "+" : ""
        return String(format: "%@%.1f", sign, d)
    }

    @ViewBuilder
    private var lastPuttSection: some View {
        VStack(spacing: fs(8)) {
            Text(lastPuttLabel)
                .font(.inter(fs(20), weight: .heavy))
                .foregroundColor(tokens.sub)
                .tracking(fs(20) * 0.22)

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                if let p = capturedPutt, phase == .settled || phase == .idle {
                    Text(String(format: "%.1f", p.actualSpeed))
                        .font(.inter(fs(64)))
                        .foregroundColor(resultColor)
                        .monospacedDigit()
                        .matchedGeometryEffect(id: "puttValue", in: heroNS)
                    Text("MPH")
                        .font(.inter(fs(22), weight: .heavy))
                        .foregroundColor(tokens.sub)
                        .tracking(fs(22) * 0.04)
                    if chipVisible || phase == .idle {
                        Text(deltaString)
                            .font(.inter(fs(48)))
                            .foregroundColor(resultColor)
                            .monospacedDigit()
                    }
                } else if capturedPutt == nil {
                    Text("—")
                        .font(.inter(fs(64)))
                        .foregroundColor(tokens.subtle)
                }
            }
            .frame(minHeight: fs(64))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .overlay(Rectangle().fill(tokens.hairline).frame(height: 1), alignment: .top)
    }
}

// MARK: - Convenience initializers (omit one or both slots)

extension SportHeroCard where Accessory == EmptyView, Middle == EmptyView {
    /// No accessory, no middle (standard / exploration / gate test / pressure).
    init(session: SessionProgress, tokens: SportTokens, tolerance: Float,
         targetSpeed: Int? = nil, targetLabel: String = "TARGET",
         targetLabelColor: Color? = nil, lastPuttLabel: String = "LAST PUTT") {
        self.init(session: session, tokens: tokens, tolerance: tolerance,
                  targetSpeed: targetSpeed, targetLabel: targetLabel,
                  targetLabelColor: targetLabelColor, lastPuttLabel: lastPuttLabel,
                  leftAccessory: { EmptyView() }, middle: { EmptyView() })
    }
}

extension SportHeroCard where Accessory == EmptyView {
    /// Middle content only (make-in-row streak dots).
    init(session: SessionProgress, tokens: SportTokens, tolerance: Float,
         targetSpeed: Int? = nil, targetLabel: String = "TARGET",
         targetLabelColor: Color? = nil, lastPuttLabel: String = "LAST PUTT",
         targetNumberScale: CGFloat = 1.0,
         @ViewBuilder middle: () -> Middle) {
        self.init(session: session, tokens: tokens, tolerance: tolerance,
                  targetSpeed: targetSpeed, targetLabel: targetLabel,
                  targetLabelColor: targetLabelColor, lastPuttLabel: lastPuttLabel,
                  targetNumberScale: targetNumberScale,
                  leftAccessory: { EmptyView() }, middle: middle)
    }
}

extension SportHeroCard where Middle == EmptyView {
    /// Left accessory only (ladder graphic).
    init(session: SessionProgress, tokens: SportTokens, tolerance: Float,
         targetSpeed: Int? = nil, targetLabel: String = "TARGET",
         targetLabelColor: Color? = nil, lastPuttLabel: String = "LAST PUTT",
         @ViewBuilder leftAccessory: () -> Accessory) {
        self.init(session: session, tokens: tokens, tolerance: tolerance,
                  targetSpeed: targetSpeed, targetLabel: targetLabel,
                  targetLabelColor: targetLabelColor, lastPuttLabel: lastPuttLabel,
                  leftAccessory: leftAccessory, middle: { EmptyView() })
    }
}
