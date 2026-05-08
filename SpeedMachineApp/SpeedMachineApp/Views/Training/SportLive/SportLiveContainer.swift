//
//  SportLiveContainer.swift
//  SpeedMachine
//
//  Composes the full Sport live session layout:
//    1. SportRecHeader
//    2. SportPassStrip (configurable per block type)
//    3. SportHeroCard (or exploration variant)
//    4. SportEndButton
//
//  The full-screen edge flash sits as an overlay on the root ZStack.
//

import SwiftUI

struct SportLiveContainer: View {
    @ObservedObject var session: SessionProgress
    let block: TrainingBlock
    let track: TrainingTrack
    let stripConfig: SportPassStripConfig
    let headerIcon: SportHeaderIcon
    let bluetoothService: BluetoothService
    var adaptiveContext: String? = nil

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.dark.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @State private var showEndAlert = false
    @EnvironmentObject var trainingViewModel: TrainingViewModel

    private var theme: LiveViewTheme { LiveViewTheme(rawValue: themeRaw) ?? .dark }
    private var isDark: Bool { theme.resolvedDark(scheme: colorScheme) }
    private var tokens: SportTokens { SportTokens.make(dark: isDark) }

    private var tolerance: Float {
        TrainingProgramLoader.shared.getToleranceForSpeed(session.currentTargetSpeed)
    }

    var body: some View {
        ZStack {
            // Background
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                SportRecHeader(
                    track: track,
                    block: block,
                    tokens: tokens,
                    icon: headerIcon,
                    isConnected: bluetoothService.isConnected,
                    adaptiveContext: adaptiveContext
                )

                SportPassStrip(
                    config: stripConfig,
                    tokens: tokens,
                    puttHistory: session.puttRecords,
                    totalPutts: session.totalPutts,
                    target: session.currentTargetSpeed,
                    tolerance: tolerance
                )

                // Hero area
                if case .exploration = stripConfig {
                    ExplorationHero(session: session, tokens: tokens)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 6)
                } else {
                    SportHeroCard(session: session, tokens: tokens, tolerance: tolerance)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 6)
                        .frame(maxHeight: .infinity)
                }

                SportEndButton(tokens: tokens, showAlert: $showEndAlert)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }

            // Edge flash overlay
            SportEdgeFlash(
                lastPuttID: session.puttRecords.count,
                inZone: session.puttRecords.last?.isInZone
            )
        }
        .alert("End Session?", isPresented: $showEndAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { trainingViewModel.endSession() }
        } message: {
            Text("Are you sure you want to end this session? Your progress will be saved.")
        }
    }
}

// MARK: - Exploration Hero (no target / no delta / no ladder)

private struct ExplorationHero: View {
    @ObservedObject var session: SessionProgress
    let tokens: SportTokens

    private var lastPutt: PuttResult? { session.puttRecords.last }
    private var isReady: Bool { lastPutt == nil }

    private var liveColor: Color {
        isReady ? tokens.sub : (lastPutt?.isInZone == true ? tokens.zone : tokens.miss)
    }

    private var mphString: String {
        guard let p = lastPutt else { return "— —" }
        return String(format: "%.1f", p.actualSpeed)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(tokens.surface)
            RoundedRectangle(cornerRadius: 24).stroke(tokens.subtle, lineWidth: 1)

            // Tint fade
            if !isReady {
                SportTintFade(
                    inZone: lastPutt?.isInZone ?? false,
                    triggerCount: session.puttRecords.count
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }

            VStack(spacing: 12) {
                Text("YOUR SPEED")
                    .font(.oswald(fs(22), weight: .semibold))
                    .foregroundColor(tokens.sub)
                    .tracking(4)

                let isLong = mphString.count >= 4
                Text(mphString)
                    .font(.oswald(isLong ? fs(160) : fs(200)))
                    .foregroundColor(isReady ? tokens.sub : liveColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .monospacedDigit()
                    .sportPopIn(trigger: session.puttRecords.count)

                Text("MPH")
                    .font(.oswald(fs(22), weight: .semibold))
                    .foregroundColor(tokens.sub)
                    .tracking(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
