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

struct SportHeroCard: View {
    @ObservedObject var session: SessionProgress
    let tokens: SportTokens
    let tolerance: Float

    @Namespace private var heroNS
    @State private var phase: HeroPuttPhase = .idle
    @State private var capturedPutt: PuttResult? = nil
    @State private var chipVisible = false
    @State private var animTask: Task<Void, Never>? = nil

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
            centerNumber
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
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
            let tStr = "\(session.currentTargetSpeed)"
            let tFont: CGFloat = tStr.count >= 2 ? fs(150) : fs(200)
            VStack(spacing: fs(8)) {
                Text(tStr)
                    .font(.inter(tFont))
                    .foregroundColor(tokens.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .monospacedDigit()
                unitRow(label: "TARGET", unitColor: tokens.fg)
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
                .foregroundColor(tokens.sub)
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
            Text("LAST PUTT")
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
