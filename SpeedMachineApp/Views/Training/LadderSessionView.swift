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
    @State private var showResetBlockAlert = false

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

                // Chromeless target + putt glide animation, with the ladder graphic
                // kept to the LEFT of the number via the hero's left-accessory slot.
                SportHeroCard(session: session, tokens: tokens, tolerance: 0.5,
                              targetSpeed: session.getCurrentLadderSpeed(),
                              leftAccessory: {
                    SportLadder(
                        targetSpeed: session.getCurrentLadderSpeed(),
                        tolerance: 0.5,
                        lastPutt: lastPutt,
                        tokens: tokens,
                        pxHeight: 300
                    )
                    .frame(width: 90, height: 300)
                    .padding(.leading, 22)
                    .padding(.trailing, 16)
                })
                .frame(maxHeight: .infinity)

                HStack(spacing: 12) {
                    SportResetButton(tokens: tokens, showAlert: $showResetBlockAlert)
                    SportEndButton(tokens: tokens, showAlert: $showEndSessionAlert)
                }
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
        .alert("Reset Block?", isPresented: $showResetBlockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) { trainingViewModel.resetBlock() }
        } message: {
            Text("This clears all putts and restarts the block from the beginning.")
        }
    }
}

