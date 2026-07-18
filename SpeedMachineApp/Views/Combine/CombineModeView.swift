//
//  CombineModeView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//
//  Combine = "test every speed once" event. Each eligible speed is hit exactly once per
//  session (see CombineGame.generateTargets). The LIVE screen is viewed at 5–6 ft with the
//  phone on the floor, so it is built on the Sport design language (SportTokens + .inter() +
//  fs()) like the Recall / Free Practice live views: a persistent board of ALL remaining
//  speeds (sorted low→high) where the current target is a big 2×2 hero tile in its sorted
//  position, and tiles disappear as their speed is hit.
//

import SwiftUI
import UIKit

// MARK: - Theme helper

/// Resolves the current SportTokens from the shared liveViewTheme preference + colorScheme.
private func combineTokens(_ themeRaw: String, _ scheme: ColorScheme) -> SportTokens {
    SportTokens.make(dark: (LiveViewTheme(rawValue: themeRaw) ?? .light).resolvedDark(scheme: scheme))
}

// MARK: - Router

struct CombineModeView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    @Environment(\.dismiss) var dismiss

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var tokens: SportTokens { combineTokens(themeRaw, colorScheme) }

    @State private var lastRecordedSpeed: Float = 0.0
    /// nil = showing the mode picker; set = showing that mode's pre-game screen.
    @State private var pickedMode: CombineMode? = nil

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            if combineViewModel.isGameActive {
                if combineViewModel.game.isComplete && combineViewModel.readyToShowComplete {
                    CombineCompleteView()
                } else {
                    ActiveCombineView()
                }
            } else if let mode = pickedMode {
                CombineStartView(mode: mode, onBack: { pickedMode = nil })
            } else {
                CombineModePickerView(onSelect: { pickedMode = $0 })
            }
        }
        .onChange(of: bluetoothService.currentSpeed) { _, newSpeed in
            if combineViewModel.isGameActive && !combineViewModel.game.isComplete {
                if newSpeed > 0 && newSpeed != lastRecordedSpeed {
                    combineViewModel.recordShot(newSpeed)
                    lastRecordedSpeed = newSpeed
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
    }
}

// MARK: - Mode Picker (taps OK — golfer is at the phone)

struct CombineModePickerView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @Environment(\.dismiss) var dismiss

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var tokens: SportTokens { combineTokens(themeRaw, colorScheme) }

    let onSelect: (CombineMode) -> Void

    private let mastery = MasteryService.shared

    @AppStorage("hasSeenCombineTour") private var seenCombineTour = false
    @State private var combineTourIndex: Int? = nil
    private let combineTourSteps = TourCopy.combine

    var body: some View {
        ZStack(alignment: .top) {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(tokens.fg)
                    }
                    Spacer()
                    Text("COMBINE")
                        .font(.inter(13, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(tokens.fg)
                    Spacer()
                    Color.clear.frame(width: 28, height: 28)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)

                Rectangle().fill(tokens.subtle).frame(height: 1)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Text("CHOOSE A MODE")
                            .font(.inter(10, weight: .bold))
                            .tracking(2.5)
                            .foregroundColor(tokens.sub)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 22)
                            .padding(.top, 22)
                            .padding(.bottom, 14)

                        VStack(spacing: 12) {
                            ForEach(CombineMode.allCases) { mode in
                                ModeCard(
                                    mode: mode,
                                    highScore: combineViewModel.highScore(for: mode),
                                    isUnlocked: mastery.isModeUnlocked(mode),
                                    lockText: mastery.lockRequirement(for: mode),
                                    tokens: tokens,
                                    onTap: { onSelect(mode) }
                                )
                            }
                        }
                        .coachmarkAnchor(0)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 20)

                        // Explains the unlock mechanism — hidden once every speed is unlocked.
                        if mastery.combineUnlockedCeiling() < 20 {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(tokens.sub)
                                    .padding(.top, 1)
                                Text("Modes unlock as you pass Training gate tests. Clear the Zone 3 Gate Test to open every speed in Combine.")
                                    .font(.inter(12, weight: .medium))
                                    .foregroundColor(tokens.sub)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 22)
                            .padding(.bottom, 32)
                        }
                    }
                    .adaptiveContentFrame(maxWidth: 680)
                }
            }
        }
        .coachmarkTour(combineTourSteps, index: $combineTourIndex, style: .sport(tokens)) {
            seenCombineTour = true
            combineTourIndex = nil
        }
        .onAppear {
            if !seenCombineTour && combineTourIndex == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if !seenCombineTour { combineTourIndex = 0 }
                }
            }
        }
    }
}

private struct ModeCard: View {
    let mode: CombineMode
    let highScore: Int
    let isUnlocked: Bool
    let lockText: String?
    let tokens: SportTokens
    let onTap: () -> Void

    var body: some View {
        Button(action: { if isUnlocked { onTap() } }) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.inter(17, weight: .bold))
                        .foregroundColor(isUnlocked ? tokens.fg : tokens.sub)
                    if isUnlocked {
                        Text(mode.rangeLabel)
                            .font(.inter(12, weight: .medium))
                            .foregroundColor(tokens.sub)
                    } else {
                        HStack(spacing: 5) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text(lockText ?? "Locked")
                                .font(.inter(12, weight: .semibold))
                        }
                        .foregroundColor(tokens.sub)
                    }
                }

                Spacer()

                if isUnlocked {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(highScore)")
                            .font(.inter(22))
                            .foregroundColor(highScore > 0 ? tokens.zone : tokens.dim)
                            .tracking(-0.5)
                        Text("BEST")
                            .font(.inter(9, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(tokens.sub)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(tokens.sub)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(tokens.dim)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(tokens.surface)
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusCard)
                    .stroke(tokens.subtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusCard))
            .opacity(isUnlocked ? 1.0 : 0.85)
        }
        .disabled(!isUnlocked)
    }
}

// MARK: - Pre-game Screen (taps OK — golfer is at the phone)

struct CombineStartView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var tokens: SportTokens { combineTokens(themeRaw, colorScheme) }

    let mode: CombineMode
    let onBack: () -> Void

    /// How many putts this game — one per eligible (unlocked) speed.
    private var puttCount: Int { MasteryService.shared.eligibleSpeeds(for: mode).count }

    private var howItWorks: [(String, String)] {
        [
            ("\(puttCount) putts — every speed once", "One shot per speed · \(mode.rangeLabel)"),
            ("Points based on precision", "Perfect 10 · Excellent 8 · Good 6 · In Zone 4 · Close 2"),
            ("Higher zones multiply your score", "Touch 1.0× → Elite 2.0×"),
            ("Every shot feeds your Stats", "Speed profiles update in real time")
        ]
    }

    var body: some View {
        ZStack(alignment: .top) {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { onBack() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(tokens.fg)
                    }
                    Spacer()
                    Text(mode.title.uppercased())
                        .font(.inter(13, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(tokens.fg)
                    Spacer()
                    Color.clear.frame(width: 28, height: 28)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)

                Rectangle().fill(tokens.subtle).frame(height: 1)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Score / mode row
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("HIGH SCORE")
                                    .font(.inter(10, weight: .bold))
                                    .tracking(2.0)
                                    .foregroundColor(tokens.sub)
                                Text("\(combineViewModel.highScore(for: mode))")
                                    .font(.inter(48))
                                    .foregroundColor(tokens.zone)
                                    .tracking(-1)
                                Text("points")
                                    .font(.inter(12, weight: .medium))
                                    .foregroundColor(tokens.sub)
                            }

                            Spacer()

                            Rectangle()
                                .fill(tokens.subtle)
                                .frame(width: 1, height: 70)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("MODE")
                                    .font(.inter(10, weight: .bold))
                                    .tracking(2.0)
                                    .foregroundColor(tokens.sub)
                                Text(mode.title)
                                    .font(.inter(28))
                                    .foregroundColor(tokens.fg)
                                    .tracking(-0.5)
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(1)
                                Text(mode.rangeLabel)
                                    .font(.inter(12, weight: .medium))
                                    .foregroundColor(tokens.sub)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 24)

                        Rectangle().fill(tokens.subtle).frame(height: 1)

                        // HOW IT WORKS
                        VStack(alignment: .leading, spacing: 0) {
                            Text("HOW IT WORKS")
                                .font(.inter(10, weight: .bold))
                                .tracking(2.5)
                                .foregroundColor(tokens.sub)
                                .padding(.horizontal, 22)
                                .padding(.top, 20)
                                .padding(.bottom, 14)

                            ForEach(howItWorks, id: \.0) { title, subtitle in
                                VStack(spacing: 0) {
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(tokens.zone)
                                            .frame(width: 20, height: 20)
                                            .padding(.top, 1)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(title)
                                                .font(.inter(15, weight: .semibold))
                                                .foregroundColor(tokens.fg)
                                            Text(subtitle)
                                                .font(.inter(12, weight: .medium))
                                                .foregroundColor(tokens.sub)
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 14)

                                    Rectangle().fill(tokens.subtle).frame(height: 1)
                                }
                            }
                        }

                        // CTA
                        Button {
                            if bluetoothService.isConnected {
                                combineViewModel.startNewGame(mode: mode)
                            }
                        } label: {
                            Text(bluetoothService.isConnected ? "Start Combine" : "Connect Device First")
                                .font(.inter(17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(bluetoothService.isConnected ? tokens.zone : tokens.sub)
                                .clipShape(Capsule())
                        }
                        .disabled(!bluetoothService.isConnected)
                        .padding(.horizontal, 22)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                    }
                    .adaptiveContentFrame(maxWidth: 680)
                }
            }
        }
    }
}

// MARK: - Live Game Screen (ZERO-TOUCH — viewed at 5–6 ft)

struct ActiveCombineView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel

    var body: some View {
        // Observe the game directly so tile removal / hero move / flash animate the instant a
        // putt lands (the router only re-renders as a side effect of the BLE speed publish).
        ActiveCombineContent(game: combineViewModel.game)
    }
}

private struct ActiveCombineContent: View {
    @ObservedObject var game: CombineGame
    @EnvironmentObject var combineViewModel: CombineViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var tokens: SportTokens { combineTokens(themeRaw, colorScheme) }

    @State private var showEndGameAlert = false
    /// The just-hit tile, held on the board showing its score for 3 s before it disappears.
    @State private var resultChip: ResultChip?
    @State private var resultTask: Task<Void, Never>?

    /// Remaining targets, sorted low→high for display. (Play order is shuffled; the board is sorted.)
    private var remainingSorted: [Int] {
        Array(game.targets.suffix(from: min(game.currentShot, game.targets.count))).sorted()
    }
    private var remainingCount: Int { max(0, game.targets.count - game.currentShot) }

    /// Board tiles = remaining speeds + the just-hit speed while its 3 s result chip is showing.
    private var displayedSpeeds: [Int] {
        var s = remainingSorted
        if let chip = resultChip, !s.contains(chip.speed) {
            s.append(chip.speed)
            s.sort()
        }
        return s
    }

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Rectangle().fill(tokens.subtle).frame(height: 1)
                remainingLabel
                SpeedBoard(speeds: displayedSpeeds, current: game.currentTarget, result: resultChip, tokens: tokens)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
                    .frame(maxHeight: .infinity)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: game.currentShot)
                lastBand
                SportEndButton(tokens: tokens, showAlert: $showEndGameAlert, title: "END GAME")
                    .padding(.horizontal, 22)
                    .padding(.top, 6)
                    .padding(.bottom, 22)
            }

            SportEdgeFlash(
                lastPuttID: game.shots.count,
                inZone: game.lastShot?.accuracy.isInZone
            )
        }
        .alert("End Game?", isPresented: $showEndGameAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { combineViewModel.endGame() }
        } message: {
            Text("End this game? Your progress will not be saved.")
        }
        // On each putt, freeze the just-hit tile in place showing its score, then clear it after 3 s
        // so it fades off the board. A faster follow-up putt replaces it immediately.
        .onChange(of: game.shots.count) { old, new in
            guard new > old, let shot = game.lastShot else { return }
            let chip = ResultChip(id: new, speed: shot.targetSpeed, points: shot.points, tier: shot.accuracy)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                resultChip = chip
            }
            resultTask?.cancel()
            resultTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        if resultChip?.id == chip.id { resultChip = nil }
                    }
                }
            }
        }
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: fs(10)) {
            SportPulsingDot(color: bluetoothService.isConnected ? tokens.zone : tokens.miss)
            Text("COMBINE · \(combineViewModel.selectedMode.title.uppercased())")
                .font(.inter(fs(14), weight: .heavy))
                .tracking(fs(14) * 0.12)
                .foregroundColor(tokens.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: fs(8))
            Text("SCORE")
                .font(.inter(fs(12), weight: .heavy))
                .tracking(fs(12) * 0.1)
                .foregroundColor(tokens.sub)
            Text("\(game.totalScore)")
                .font(.inter(fs(34)))
                .foregroundColor(tokens.fg)
                .monospacedDigit()
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var remainingLabel: some View {
        Text("REMAINING · \(remainingCount) LEFT")
            .font(.inter(fs(11), weight: .heavy))
            .tracking(fs(11) * 0.2)
            .foregroundColor(tokens.sub)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 12)
    }

    // MARK: last-putt band (sized for 5–6 ft — +points is the largest element)

    @ViewBuilder
    private var lastBand: some View {
        let shot = game.lastShot
        let made = shot?.accuracy.isInZone ?? false
        let color = made ? tokens.zone : tokens.miss

        VStack(spacing: 0) {
            Rectangle().fill(tokens.hairline).frame(height: 1)

            if let shot = shot {
                HStack(alignment: .firstTextBaseline, spacing: fs(12)) {
                    Text("LAST")
                        .font(.inter(fs(16), weight: .heavy))
                        .tracking(fs(16) * 0.16)
                        .foregroundColor(tokens.sub)
                    Text(shot.actualSpeed.toSpeedString())
                        .font(.inter(fs(56)))
                        .foregroundColor(color)
                        .monospacedDigit()
                    Text(String(format: "%+.1f", shot.actualSpeed - Float(shot.targetSpeed)))
                        .font(.inter(fs(40)))
                        .foregroundColor(color)
                        .monospacedDigit()

                    Spacer(minLength: fs(8))

                    VStack(alignment: .trailing, spacing: 0) {
                        Text("+\(shot.points)")
                            .font(.inter(fs(64)))
                            .foregroundColor(color)
                            .monospacedDigit()
                        Text(shot.accuracy.rawValue.uppercased())
                            .font(.inter(fs(18), weight: .heavy))
                            .tracking(fs(18) * 0.12)
                            .foregroundColor(tokens.sub)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 22)
                .padding(.vertical, fs(8))
            } else {
                HStack(spacing: fs(12)) {
                    Text("LAST")
                        .font(.inter(fs(16), weight: .heavy))
                        .tracking(fs(16) * 0.16)
                        .foregroundColor(tokens.sub)
                    Text("—")
                        .font(.inter(fs(56)))
                        .foregroundColor(tokens.subtle)
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.vertical, fs(8))
            }
        }
    }
}

// MARK: - Remaining-speeds board

/// A board tile that was just hit, held in place showing its score for 3 s before it fades away.
private struct ResultChip: Equatable {
    let id: Int          // game.shots.count when this putt landed
    let speed: Int
    let points: Int
    let tier: AccuracyTier
    var made: Bool { tier.isInZone }
}

private enum TileKind { case idle, hero, result }

/// The persistent board of remaining speeds. Renders every displayed speed (sorted ascending):
/// the `current` target is the big 2×2 hero tile, a just-hit speed becomes a 2×2 score chip, the
/// rest are uniform tiles. Laid out by `SpeedBoardLayout`, which packs each 2×2 footprint into the
/// grid at its sorted position.
private struct SpeedBoard: View {
    let speeds: [Int]      // sorted ascending; includes the result-chip speed while it's showing
    let current: Int
    let result: ResultChip?
    let tokens: SportTokens

    // Fewer columns ⇒ physically larger chips (one tile is large at a time, so the rest still fit).
    private var columns: Int { isIPad ? 4 : 3 }

    var body: some View {
        SpeedBoardLayout(columns: columns, spacing: 10) {
            ForEach(speeds, id: \.self) { speed in
                let kind = tileKind(for: speed)
                SpeedTileView(speed: speed, kind: kind, result: result, tokens: tokens)
                    .layoutValue(key: IsLargeTile.self, value: kind != .idle)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func tileKind(for speed: Int) -> TileKind {
        // Only ONE tile is ever large. While a score chip is showing it owns the highlight; the
        // next target stays a normal idle tile until the chip clears (3 s later), then swells.
        if let r = result {
            return r.speed == speed ? .result : .idle
        }
        return speed == current ? .hero : .idle
    }
}

/// One board tile. Stable identity across kind changes (driven by `kind`) so the custom layout
/// animates the swell / morph / reposition rather than rebuilding the view.
private struct SpeedTileView: View {
    let speed: Int
    let kind: TileKind
    let result: ResultChip?
    let tokens: SportTokens

    var body: some View {
        switch kind {
        case .hero:   heroTile
        case .result: resultTile
        case .idle:   idleTile
        }
    }

    // Current target — big number sized to read at 5–6 ft.
    private var heroTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(tokens.zone)
            VStack(spacing: 0) {
                Text("NEXT")
                    .font(.inter(fs(14), weight: .heavy))
                    .tracking(fs(14) * 0.18)
                    .foregroundColor(Color(hex: "0A3D1C"))
                Text("\(speed)")
                    .font(.inter(fs(180)))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .monospacedDigit()
                Text("MPH · HIT NOW")
                    .font(.inter(fs(14), weight: .heavy))
                    .tracking(fs(14) * 0.14)
                    .foregroundColor(Color(hex: "0A3D1C"))
            }
            .padding(6)
        }
        .overlay(HeroPulseRing(tokens: tokens))
    }

    // Just-hit tile — holds the score (green made / red miss) for 3 s, then fades off the board.
    private var resultTile: some View {
        let made = result?.made ?? false
        let points = result?.points ?? 0
        let tierName = (result?.tier.rawValue ?? "").uppercased()
        return ZStack {
            RoundedRectangle(cornerRadius: 18).fill(made ? tokens.zone : tokens.miss)
            VStack(spacing: 0) {
                Text("\(speed) MPH")
                    .font(.inter(fs(14), weight: .heavy))
                    .tracking(fs(14) * 0.14)
                    .foregroundColor(.white.opacity(0.85))
                Text("+\(points)")
                    .font(.inter(fs(170)))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .monospacedDigit()
                Text(tierName)
                    .font(.inter(fs(14), weight: .heavy))
                    .tracking(fs(14) * 0.14)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(6)
        }
    }

    private var idleTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(tokens.subtle)
            Text("\(speed)")
                .font(.inter(fs(56)))
                .foregroundColor(tokens.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .monospacedDigit()
        }
    }
}

/// Gentle pulsing ring around the hero tile so the current target reads as "live" from 5–6 ft.
private struct HeroPulseRing: View {
    let tokens: SportTokens
    @State private var on = false

    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .stroke(tokens.zone, lineWidth: 4)
            .opacity(on ? 0.0 : 0.45)
            .scaleEffect(on ? 1.04 : 1.0)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
            .allowsHitTesting(false)
    }
}

// MARK: - Custom grid layout (hero = 2×2, packed around by uniform tiles)

private struct IsLargeTile: LayoutValueKey {
    static let defaultValue: Bool = false
}

/// A fixed-column grid where subviews flagged via `IsLargeTile` (the current target + any showing
/// score chip) occupy a 2×2 footprint and the rest occupy 1×1. Cells fill the available width; cell
/// height shrinks to fit all rows in the available height, so the whole board is always visible.
private struct SpeedBoardLayout: Layout {
    let columns: Int
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let cols = max(1, columns)
        let cellW = (bounds.width - spacing * CGFloat(cols - 1)) / CGFloat(cols)

        let placements = computePlacements(subviews: subviews, cols: cols)
        let rows = max(1, placements.rowsUsed)
        let cellH = (bounds.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)

        for item in placements.items {
            let x = bounds.minX + CGFloat(item.col) * (cellW + spacing)
            let y = bounds.minY + CGFloat(item.row) * (cellH + spacing)
            let w = cellW * CGFloat(item.span) + spacing * CGFloat(item.span - 1)
            let h = cellH * CGFloat(item.span) + spacing * CGFloat(item.span - 1)
            subviews[item.index].place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: w, height: h)
            )
        }
    }

    // MARK: occupancy packing

    private struct Item { let index: Int; let row: Int; let col: Int; let span: Int }
    private struct Placements { let items: [Item]; let rowsUsed: Int }

    private func computePlacements(subviews: Subviews, cols: Int) -> Placements {
        var occupied = Set<Int>()   // key = row * cols + col
        func cellFree(_ row: Int, _ col: Int, _ span: Int) -> Bool {
            if col + span > cols { return false }
            for r in row..<(row + span) {
                for c in col..<(col + span) where occupied.contains(r * cols + c) { return false }
            }
            return true
        }
        func occupy(_ row: Int, _ col: Int, _ span: Int) {
            for r in row..<(row + span) {
                for c in col..<(col + span) { occupied.insert(r * cols + c) }
            }
        }
        func firstFree(span: Int) -> (Int, Int) {
            var row = 0
            while true {
                var col = 0
                while col <= cols - span {
                    if cellFree(row, col, span) { return (row, col) }
                    col += 1
                }
                row += 1
            }
        }

        var items: [Item] = []
        var rowsUsed = 0
        for index in subviews.indices {
            let span = subviews[index][IsLargeTile.self] ? 2 : 1
            let (row, col) = firstFree(span: span)
            occupy(row, col, span)
            items.append(Item(index: index, row: row, col: col, span: span))
            rowsUsed = max(rowsUsed, row + span)
        }
        return Placements(items: items, rowsUsed: rowsUsed)
    }
}

// MARK: - Complete Screen

struct CombineCompleteView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @Environment(\.dismiss) var dismiss

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var tokens: SportTokens { combineTokens(themeRaw, colorScheme) }

    var game: CombineGame { combineViewModel.game }

    var isNewHighScore: Bool { game.totalScore >= combineViewModel.highScore }

    var scoreRating: String {
        let pct = Double(game.totalScore) / Double(max(1, combineViewModel.maxScore))
        if pct >= 0.75 { return "Outstanding!" }
        if pct >= 0.60 { return "Excellent!" }
        if pct >= 0.45 { return "Great Job!" }
        if pct >= 0.30 { return "Good Effort!" }
        return "Keep Practicing!"
    }

    private var scoringPutts: Int { game.shots.filter { $0.accuracy != .miss }.count }
    private var missedPutts: Int { game.shots.filter { $0.accuracy == .miss }.count }
    private var averagePointsPerPutt: Double {
        guard !game.shots.isEmpty else { return 0 }
        return Double(game.totalScore) / Double(game.shots.count)
    }

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 40)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: fs(56)))
                        .foregroundColor(isNewHighScore ? tokens.zone : tokens.sub)
                        .padding(.bottom, 16)

                    if isNewHighScore {
                        Text("NEW HIGH SCORE")
                            .font(.inter(fs(32)))
                            .foregroundColor(tokens.zone)
                            .tracking(1)
                    } else {
                        Text("COMBINE COMPLETE")
                            .font(.inter(fs(32)))
                            .foregroundColor(tokens.fg)
                            .tracking(1)
                    }

                    Text(scoreRating)
                        .font(.inter(fs(16), weight: .medium))
                        .foregroundColor(tokens.sub)
                        .padding(.top, 6)

                    Spacer(minLength: 24)

                    Text("\(game.totalScore)")
                        .font(.inter(fs(96)))
                        .foregroundColor(tokens.fg)
                        .tracking(-2)

                    Text("of \(combineViewModel.maxScore) possible points")
                        .font(.inter(fs(14), weight: .medium))
                        .foregroundColor(tokens.sub)
                        .padding(.top, 4)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tokens.subtle)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tokens.zone)
                                .frame(width: max(0, geo.size.width * CGFloat(game.totalScore) / CGFloat(max(1, combineViewModel.maxScore))), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .padding(.bottom, 32)

                    // Summary stats
                    VStack(spacing: 0) {
                        HStack {
                            Text("AVG POINTS / PUTT")
                                .font(.inter(13, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(tokens.fg.opacity(0.75))
                            Spacer()
                            Text(String(format: "%.1f", averagePointsPerPutt))
                                .font(.inter(20))
                                .foregroundColor(tokens.fg)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)

                        Rectangle().fill(tokens.subtle).frame(height: 1).padding(.horizontal, 32)

                        HStack {
                            Text("SCORING PUTTS")
                                .font(.inter(13, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(tokens.fg.opacity(0.75))
                            Spacer()
                            Text("\(scoringPutts)")
                                .font(.inter(20))
                                .foregroundColor(tokens.fg)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)

                        Rectangle().fill(tokens.subtle).frame(height: 1).padding(.horizontal, 32)

                        HStack {
                            Text("MISSED PUTTS")
                                .font(.inter(13, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(tokens.miss)
                            Spacer()
                            Text("\(missedPutts)")
                                .font(.inter(20))
                                .foregroundColor(tokens.miss)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                    }
                    .padding(.bottom, 32)

                    // Buttons
                    VStack(spacing: 10) {
                        Button {
                            combineViewModel.startNewGame(mode: combineViewModel.selectedMode)
                        } label: {
                            Text("Play Again")
                                .font(.inter(17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(tokens.zone)
                                .clipShape(Capsule())
                        }

                        Button {
                            combineViewModel.endGame()
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.inter(17, weight: .bold))
                                .foregroundColor(tokens.fg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color.clear)
                                .overlay(Capsule().stroke(tokens.subtle, lineWidth: 1.5))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                    .adaptiveContentFrame(maxWidth: 680)
                }
            }
        }
    }
}

// MARK: - Preview (board layout / animation — self-contained, no env objects)

#if DEBUG
#Preview("Combine board") {
    CombineBoardPreviewHarness()
}

private struct CombineBoardPreviewHarness: View {
    @State private var remaining: [Int] = Array(3...20)
    @State private var current: Int = 12
    private let tokens = SportTokens.make(dark: false)

    var body: some View {
        VStack(spacing: 16) {
            Text("REMAINING · \(remaining.count) LEFT")
                .font(.inter(fs(11), weight: .heavy))
                .foregroundColor(tokens.sub)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)

            SpeedBoard(speeds: remaining.sorted(), current: current, result: nil, tokens: tokens)
                .padding(.horizontal, 18)
                .frame(maxHeight: .infinity)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: current)

            Button("Hit \(current)") {
                remaining.removeAll { $0 == current }
                current = remaining.randomElement() ?? 0
            }
            .font(.inter(17, weight: .bold))
            .padding(.bottom, 24)
        }
        .background(tokens.bg.ignoresSafeArea())
    }
}
#endif
