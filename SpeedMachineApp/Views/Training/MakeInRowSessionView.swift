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
    var lastPutt: PuttResult? { session.puttRecords.last }

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                SportRecHeader(day: day, block: block, tokens: tokens, icon: .rec,
                               isConnected: bluetoothService.isConnected)

                SportPassStrip(
                    config: .makeInRow(puttsHit: session.inZonePutts,
                                       consecutive: session.consecutiveSuccesses,
                                       goal: goal),
                    tokens: tokens,
                    puttHistory: session.puttRecords,
                    totalPutts: session.totalPutts,
                    target: session.currentTargetSpeed,
                    tolerance: 0.5
                )

                // Chromeless target
                Spacer(minLength: 0)
                let tStr = "\(session.currentTargetSpeed)"
                VStack(spacing: fs(8)) {
                    Text(tStr)
                        .font(.inter(tStr.count >= 2 ? fs(150) : fs(200)))
                        .foregroundColor(tokens.fg)
                        .lineLimit(1).minimumScaleFactor(0.3).monospacedDigit()
                    HStack(spacing: 14) {
                        Text("MPH").font(.inter(fs(24), weight: .heavy)).foregroundColor(tokens.fg).tracking(fs(24) * 0.06)
                        Rectangle().fill(tokens.subtle).frame(width: 1, height: fs(20))
                        Text("TARGET").font(.inter(fs(24), weight: .heavy)).foregroundColor(tokens.sub).tracking(fs(24) * 0.22)
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)

                // Consecutive-hits streak dots
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

                SportLastPutt(lastPutt: lastPutt, tokens: tokens)

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
