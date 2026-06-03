import SwiftUI

// Make-in-row live session (mockup 09): header → pass strip (PUTTS HIT /
// PUTTS REMAINING + tachs) → chromeless target → CONSECUTIVE HITS streak dots
// → LAST PUTT → END SESSION.

struct MakeInRowSessionView: View {
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

    private var goal: Int { block.consecutiveRequired ?? 5 }

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                SportRecHeader(day: day, block: block, tokens: tokens, icon: .rec,
                               isConnected: bluetoothService.isConnected)

                SportPassStrip(
                    config: .makeInRow(puttsTaken: session.currentPutt,
                                       consecutive: session.consecutiveSuccesses,
                                       goal: goal),
                    tokens: tokens,
                    puttHistory: session.puttRecords,
                    totalPutts: session.totalPutts,
                    target: session.currentTargetSpeed,
                    tolerance: 0.5
                )

                // Chromeless target + putt glide animation, with the consecutive-hits
                // streak dots in the hero's middle slot (above the LAST PUTT readout).
                SportHeroCard(session: session, tokens: tokens, tolerance: 0.5,
                              targetNumberScale: 1.25, middle: {
                    VStack(spacing: 12) {
                        Text("CONSECUTIVE HITS")
                            .font(.inter(fs(20), weight: .heavy))
                            .foregroundColor(tokens.sub)
                            .tracking(fs(20) * 0.22)
                        HStack(spacing: 14) {
                            ForEach(0..<goal, id: \.self) { i in
                                let hit = i < session.consecutiveSuccesses
                                ZStack {
                                    Circle().fill(hit ? tokens.zone : Color.clear)
                                    Circle().stroke(hit ? tokens.zone : tokens.subtle, lineWidth: 2.5)
                                    Text("\(i + 1)")
                                        .font(.inter(fs(22), weight: .black))
                                        .foregroundColor(hit ? .white : Color(hex: "d4d4d4"))
                                }
                                .frame(width: fs(48), height: fs(48))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 6)
                })
                .frame(maxHeight: .infinity)

                SportEndButton(tokens: tokens, showAlert: $showEndSessionAlert)
                    .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 22)
            }

            SportEdgeFlash(lastPuttID: session.puttRecords.count,
                           inZone: session.puttRecords.last?.isInZone)
        }
        .alert("End Session?", isPresented: $showEndSessionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { trainingViewModel.endSession() }
        } message: {
            Text("Are you sure you want to end this session? Your progress will be saved.")
        }
    }
}
