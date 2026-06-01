import SwiftUI

// MARK: - Sport Live Container
// Composes header + pass strip + hero card + end button + edge flash.
// Used by ActiveSessionView, ExplorationSessionView, GateTestSessionView,
// and MakeInRowSessionView.

struct SportLiveContainer: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let day: TrainingDay
    let stripConfig: SportPassStripConfig
    var headerIcon: SportHeaderIcon = .rec
    var endTitle: String = "END SESSION"
    var endAccent: Color? = nil

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @State private var showEndSessionAlert = false

    private var tokens: SportTokens {
        let isDark = (LiveViewTheme(rawValue: themeRaw) ?? .light).resolvedDark(scheme: colorScheme)
        return SportTokens.make(dark: isDark)
    }

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                SportRecHeader(
                    day: day,
                    block: block,
                    tokens: tokens,
                    icon: headerIcon,
                    isConnected: bluetoothService.isConnected,
                    adaptiveContext: trainingViewModel.adaptiveBlockContext
                )

                SportPassStrip(
                    config: stripConfig,
                    tokens: tokens,
                    puttHistory: session.puttRecords,
                    totalPutts: session.totalPutts,
                    target: session.currentTargetSpeed,
                    tolerance: 0.5
                )

                // Chromeless hero fills remaining space; end button pinned below
                SportHeroCard(session: session, tokens: tokens, tolerance: 0.5)
                    .frame(maxHeight: .infinity)

                SportEndButton(tokens: tokens, showAlert: $showEndSessionAlert,
                               title: endTitle, accent: endAccent)
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
            Text("Are you sure you want to end this session? Your progress will be saved.")
        }
    }
}
