import SwiftUI

// Ladder live session (mockup 10): header → 2-col pass strip (RUNG / PUTTS HIT)
// → body (thin tick-track ladder graphic on the left + chromeless target on the
// right) → LAST PUTT section → red outlined END SESSION. No bordered panels.

struct LadderSessionView: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let day: TrainingDay

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var showEndSessionAlert = false

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme

    private var tokens: SportTokens {
        let isDark = (LiveViewTheme(rawValue: themeRaw) ?? .light).resolvedDark(scheme: colorScheme)
        return SportTokens.make(dark: isDark)
    }

    var lastPutt: PuttResult? { session.puttRecords.last }
    var totalRungs: Int { session.ladderSpeeds.count }
    var currentRung: Int { session.currentRung + 1 }

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                SportRecHeader(
                    day: day,
                    block: block,
                    tokens: tokens,
                    icon: .rec,
                    isConnected: bluetoothService.isConnected
                )

                SportPassStrip(
                    config: .ladder(currentRung: currentRung,
                                    totalRungs: totalRungs,
                                    puttsHit: session.currentPutt),
                    tokens: tokens
                )

                LadderBody(
                    targetSpeed: session.getCurrentLadderSpeed(),
                    lastPutt: lastPutt,
                    tokens: tokens
                )
                .frame(maxHeight: .infinity)

                SportLastPutt(lastPutt: lastPutt, tokens: tokens)

                SportEndButton(tokens: tokens, showAlert: $showEndSessionAlert)
                    .padding(.horizontal, 22)
                    .padding(.top, 4)
                    .padding(.bottom, 22)
            }

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

// MARK: - Ladder body (graphic + chromeless target)

private struct LadderBody: View {
    let targetSpeed: Int
    let lastPutt: PuttResult?
    let tokens: SportTokens

    var body: some View {
        GeometryReader { geo in
            let h = min(max(200, geo.size.height - 24), 360)
            HStack(alignment: .center, spacing: 16) {
                SportLadder(
                    targetSpeed: targetSpeed,
                    tolerance: 0.5,
                    lastPutt: lastPutt,
                    tokens: tokens,
                    pxHeight: h
                )
                .frame(width: 90, height: h)

                let tStr = "\(targetSpeed)"
                VStack(spacing: fs(8)) {
                    Text(tStr)
                        .font(.inter(tStr.count >= 2 ? fs(150) : fs(180)))
                        .foregroundColor(tokens.fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .monospacedDigit()
                    HStack(spacing: 14) {
                        Text("MPH")
                            .font(.inter(fs(24), weight: .heavy))
                            .foregroundColor(tokens.fg)
                            .tracking(fs(24) * 0.06)
                        Rectangle().fill(tokens.subtle).frame(width: 1, height: fs(20))
                        Text("TARGET")
                            .font(.inter(fs(24), weight: .heavy))
                            .foregroundColor(tokens.sub)
                            .tracking(fs(24) * 0.22)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 22)
        }
    }
}

// MARK: - Shared LAST PUTT section (mockup .last-putt, static)

struct SportLastPutt: View {
    let lastPutt: PuttResult?
    let tokens: SportTokens
    var label: String = "LAST PUTT"

    private var resultColor: Color {
        guard let p = lastPutt else { return tokens.sub }
        return p.isInZone ? tokens.zone : tokens.miss
    }

    private var deltaString: String {
        guard let p = lastPutt else { return "" }
        let d = p.actualSpeed - Float(p.targetSpeed)
        return String(format: "%@%.1f", d > 0 ? "+" : "", d)
    }

    var body: some View {
        VStack(spacing: fs(8)) {
            Text(label)
                .font(.inter(fs(20), weight: .heavy))
                .foregroundColor(tokens.sub)
                .tracking(fs(20) * 0.22)

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                if let p = lastPutt {
                    Text(String(format: "%.1f", p.actualSpeed))
                        .font(.inter(fs(64)))
                        .foregroundColor(resultColor)
                        .monospacedDigit()
                    Text("MPH")
                        .font(.inter(fs(22), weight: .heavy))
                        .foregroundColor(tokens.sub)
                        .tracking(fs(22) * 0.04)
                    Text(deltaString)
                        .font(.inter(fs(48)))
                        .foregroundColor(resultColor)
                        .monospacedDigit()
                } else {
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
