//
//  SportHeroCard.swift
//  SpeedMachine
//
//  Hero card — three-phase putt animation:
//    .idle    → TARGET SPEED label + giant number, bright fg
//    .showing → PUTT SPEED shown giant (zone/miss colour) for 2 s; readout dims
//    .settled → putt number glides via matchedGeometryEffect to PUTT SPEED readout strip;
//               target fades back; delta chip pops ~0.6 s after glide starts
//
//  Ladder spans full card height (12 pt padding top + bottom).
//  Readout strip is left-padded to clear the ladder.
//

import SwiftUI

// MARK: - Display phase

private enum HeroPuttPhase: Equatable {
    case idle
    case showing
    case settled
}

// MARK: - Hero card

struct SportHeroCard: View {
    @ObservedObject var session: SessionProgress
    let tokens: SportTokens
    let tolerance: Float

    @Namespace private var heroNS
    @State private var phase: HeroPuttPhase = .idle
    @State private var capturedPutt: PuttResult? = nil
    @State private var chipVisible = false
    @State private var animTask: Task<Void, Never>? = nil

    // MARK: Computed

    private var hitRate: Int {
        guard session.currentPutt > 0 else { return 0 }
        return Int(session.zoneAccuracy * 100)
    }

    private var borderColor: Color {
        guard let p = capturedPutt, phase != .idle else { return tokens.subtle }
        return p.isInZone ? tokens.zone : tokens.miss
    }

    // Width of ladder column (width 60 + leading pad 8 + buffer 8 = 76)
    private let ladderClearance: CGFloat = 76

    // MARK: Animation trigger

    private func onNewPutt(_ putt: PuttResult) {
        animTask?.cancel()
        chipVisible = false
        capturedPutt = putt

        phase = .showing

        animTask = Task {
            // 3-second display window
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }

            // Begin glide
            await MainActor.run {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    phase = .settled
                }
            }

            // Delta chip pops after glide (~0.62 s)
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
        ZStack {
            // ── Card surfaces ─────────────────────────────────────────
            RoundedRectangle(cornerRadius: 24).fill(tokens.surface)
            RoundedRectangle(cornerRadius: 24)
                .stroke(borderColor, lineWidth: 2)
                .animation(.easeInOut(duration: 0.3), value: phase)
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.black, lineWidth: 3)
                .padding(-4)

            // Tint fade
            if let p = capturedPutt, phase != .idle {
                SportTintFade(inZone: p.isInZone, triggerCount: session.puttRecords.count)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }

            // ── Ladder: full card height, 12 pt padding each end ──────
            GeometryReader { geo in
                let ladderH = max(60, geo.size.height - 24)
                HStack(spacing: 0) {
                    SportLadder(
                        targetSpeed: session.currentTargetSpeed,
                        tolerance: tolerance,
                        lastPutt: phase == .settled ? nil : capturedPutt,
                        tokens: tokens,
                        pxHeight: ladderH
                    )
                    .frame(width: 60, height: ladderH)
                    .frame(maxHeight: .infinity)   // centre in geo height
                    .padding(.leading, 8)
                    Spacer()
                }
            }

            // ── Content overlay ───────────────────────────────────────
            VStack(spacing: 0) {

                // HIT RATE — top right
                HStack {
                    Spacer()
                    CornerStat(label: "HIT RATE", value: "\(hitRate)%",
                               color: tokens.zone, tokens: tokens)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Spacer(minLength: 0)

                // Giant centre number
                centerNumber
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.trailing, 16)

                Spacer(minLength: 0)

                // Readout strip — left edge clears the ladder
                HeroReadout(
                    capturedPutt: capturedPutt,
                    phase: phase,
                    chipVisible: chipVisible,
                    tokens: tokens,
                    namespace: heroNS
                )
                .padding(.leading, ladderClearance)
                .padding(.trailing, 12)
                .padding(.bottom, 14)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .onChange(of: session.puttRecords.count) { _, count in
            guard count > 0, let p = session.puttRecords.last else { return }
            onNewPutt(p)
        }
    }

    // MARK: - Centre number

    @ViewBuilder
    private var centerNumber: some View {
        ZStack {
            // ── TARGET SPEED (shown in .idle and .settled) ────────────
            let tStr = "\(session.currentTargetSpeed)"
            let tFont: CGFloat = tStr.count >= 2 ? fs(190) : fs(230)
            VStack(spacing: 2) {
                Text("TARGET SPEED")
                    .font(.inter(fs(24), weight: .semibold))
                    .foregroundColor(tokens.sub)
                    .tracking(4)
                Text(tStr)
                    .font(.inter(tFont))
                    .foregroundColor(tokens.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.25)
                    .monospacedDigit()
                Text("MPH")
                    .font(.inter(fs(38), weight: .semibold))
                    .foregroundColor(tokens.sub)
                    .tracking(4)
            }
            .opacity(phase == .showing ? 0 : 1)

            // ── PUTT SPEED (shown in .showing; number glides on .settled) ──
            if let p = capturedPutt, phase == .showing {
                let pStr = String(format: "%.1f", p.actualSpeed)
                let pFont: CGFloat = pStr.count >= 4 ? fs(170) : fs(200)
                let col: Color = p.isInZone ? tokens.zone : tokens.miss

                VStack(spacing: 2) {
                    Text(pStr)
                        .font(.inter(pFont))
                        .foregroundColor(col)
                        .lineLimit(1)
                        .minimumScaleFactor(0.25)
                        .monospacedDigit()
                        // Only the number text glides to the readout
                        .matchedGeometryEffect(id: "puttValue", in: heroNS)
                    Text("MPH")
                        .font(.inter(fs(38), weight: .semibold))
                        .foregroundColor(tokens.sub)
                        .tracking(4)
                }
                .sportPopIn(trigger: session.puttRecords.count)
            }
        }
    }
}

// MARK: - Readout strip

private struct HeroReadout: View {
    let capturedPutt: PuttResult?
    let phase: HeroPuttPhase
    let chipVisible: Bool
    let tokens: SportTokens
    var namespace: Namespace.ID

    private var isSettled: Bool { phase == .settled }

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

    var body: some View {
        HStack(alignment: .center, spacing: 0) {

            // PUTT SPEED label + glided number
            VStack(alignment: .leading, spacing: 2) {
                Text("LAST PUTT SPEED")
                    .font(.system(size: fs(13), weight: .heavy))
                    .foregroundColor(isSettled ? tokens.sub : tokens.subtle)
                    .tracking(2)

                if let p = capturedPutt, isSettled {
                    Text(String(format: "%.1f", p.actualSpeed))
                        .font(.inter(fs(52)))
                        .foregroundColor(resultColor)
                        .monospacedDigit()
                        // matchedGeometryEffect destination — number glides here
                        .matchedGeometryEffect(id: "puttValue", in: namespace)
                }
            }
            .padding(.leading, 12)

            Spacer()

            // Delta chip — pops in after glide
            if isSettled && chipVisible, capturedPutt != nil {
                Text(deltaString)
                    .font(.inter(fs(34)))
                    .foregroundColor(resultColor)
                    .monospacedDigit()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(resultColor.opacity(0.13))
                    .cornerRadius(8)
                    .padding(.trailing, 12)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .frame(height: fs(90))
        .background(
            tokens.isDark
                ? Color.black.opacity(0.30)
                : Color.white.opacity(0.55)
        )
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tokens.subtle, lineWidth: 1))
    }
}

// MARK: - Corner stat

private struct CornerStat: View {
    let label: String
    let value: String
    let color: Color
    let tokens: SportTokens

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.system(size: fs(14), weight: .bold))
                .foregroundColor(tokens.sub)
                .tracking(3)
            Text(value)
                .font(.inter(fs(34)))
                .foregroundColor(color)
                .monospacedDigit()
        }
    }
}
