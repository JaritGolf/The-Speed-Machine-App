//
//  PracticeModeView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//
//  Free Practice — pick a speed (or speeds) + a putt count (or go open-ended), then grind a
//  blocked-practice block. The live view tracks putts taken / left, putts made, and a running
//  make %; there is no "putts needed" pass gate.
//
//  USAGE CONTEXT: like Recall, the phone lies face-up on the floor ~5–6 ft away, so the active
//  loop is ZERO-TOUCH — putts arrive over BLE and the screen auto-advances. Taps happen only at
//  the start screen and the end-of-session summary. Styled with the SportTokens design language
//  (theme-aware colors + Inter type), matching the SportLive / Recall screens.
//

import SwiftUI
import UIKit

// MARK: - Theme helper

/// Resolves the current SportTokens from the shared liveViewTheme preference + colorScheme.
private func practiceTokens(_ themeRaw: String, _ scheme: ColorScheme) -> SportTokens {
    SportTokens.make(dark: (LiveViewTheme(rawValue: themeRaw) ?? .light).resolvedDark(scheme: scheme))
}

// MARK: - Router

struct PracticeModeView: View {
    @EnvironmentObject var practiceViewModel: PracticeViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var tokens: SportTokens { practiceTokens(themeRaw, colorScheme) }

    @State private var lastRecordedSpeed: Float = 0.0

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            if !practiceViewModel.isActive || practiceViewModel.session == nil {
                PracticeStartView()
            } else if practiceViewModel.phase == .complete {
                PracticeCompleteView()
            } else {
                ActivePracticeView()
            }
        }
        .onChange(of: bluetoothService.currentSpeed) { _, newSpeed in
            guard practiceViewModel.isActive, practiceViewModel.phase == .active else { return }
            if newSpeed > 0 && newSpeed != lastRecordedSpeed {
                practiceViewModel.recordPutt(newSpeed)
                lastRecordedSpeed = newSpeed
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }
}

// MARK: - Start (taps OK — golfer is at the phone)

struct PracticeStartView: View {
    @EnvironmentObject var practiceViewModel: PracticeViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    @Environment(\.dismiss) var dismiss

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var tokens: SportTokens { practiceTokens(themeRaw, colorScheme) }

    @State private var selectedSpeeds: Set<Int> = Set(PracticeViewModel.defaultSpeeds)
    @State private var order: PracticeOrder = .random
    @State private var puttCount: Int = PracticeViewModel.defaultCount
    @State private var isInfinite: Bool = false

    private let allSpeeds = Array(PracticeViewModel.speedRange)
    private let countBounds = 5...100

    private var canStart: Bool { bluetoothService.isConnected && !selectedSpeeds.isEmpty }

    @AppStorage("hasSeenPracticeTour") private var seenPracticeTour = false
    @State private var practiceTourIndex: Int? = nil
    private let practiceTourSteps = TourCopy.practice

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    Image(systemName: "target")
                        .font(.system(size: 70))
                        .foregroundColor(tokens.zone)
                        .padding(.top, 8)

                    VStack(spacing: 8) {
                        Text("Free Practice")
                            .font(.inter(34))
                            .foregroundColor(tokens.fg)
                        Text("Pick your speed (or speeds) and how many putts — then just hit them.")
                            .font(.inter(17, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundColor(tokens.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    speedCard
                        .coachmarkAnchor(0)
                        .id(0)
                    if selectedSpeeds.count > 1 { orderCard }
                    countCard
                        .coachmarkAnchor(1)
                        .id(1)

                    Button {
                        if canStart {
                            practiceViewModel.start(speeds: Array(selectedSpeeds).sorted(),
                                                    order: order,
                                                    count: isInfinite ? nil : puttCount)
                        }
                    } label: {
                        Text(startTitle)
                            .font(.inter(20, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(tokens.zone.opacity(canStart ? 1 : 0.5))
                            .cornerRadius(14)
                    }
                    .disabled(!canStart)
                    .coachmarkAnchor(2)
                    .id(2)
                }
                .padding()
                .adaptiveContentFrame(maxWidth: 680)
            }
            .background(tokens.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: practiceTourIndex) { _, i in
                if let i { withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(i, anchor: .center) } }
            }
            }
        }
        .navigationViewStyle(.stack)
        .coachmarkTour(practiceTourSteps, index: $practiceTourIndex, style: .sport(tokens)) {
            seenPracticeTour = true
            practiceTourIndex = nil
        }
        .onAppear {
            if !seenPracticeTour && practiceTourIndex == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if !seenPracticeTour { practiceTourIndex = 0 }
                }
            }
        }
    }

    private var startTitle: String {
        if !bluetoothService.isConnected { return "Connect Device First" }
        if selectedSpeeds.isEmpty { return "Pick a Speed" }
        return "Start"
    }

    // MARK: Speed selection

    private var speedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Target speed")
                    .font(.inter(17, weight: .semibold))
                    .foregroundColor(tokens.fg)
                Spacer()
                Text("\(selectedSpeeds.count) selected")
                    .font(.inter(15, weight: .medium))
                    .foregroundColor(tokens.sub)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(allSpeeds, id: \.self) { speed in
                    let isSel = selectedSpeeds.contains(speed)
                    Text("\(speed)")
                        .font(.inter(20, weight: .heavy))
                        .foregroundColor(isSel ? .white : tokens.fg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSel ? tokens.zone : tokens.subtle)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                        .onTapGesture { toggle(speed) }
                }
            }
            Text("MPH")
                .font(.inter(13, weight: .medium))
                .foregroundColor(tokens.dim)
        }
        .padding()
        .cardBackground(tokens)
    }

    private func toggle(_ speed: Int) {
        withAnimation(.easeOut(duration: 0.12)) {
            if selectedSpeeds.contains(speed) {
                // Keep at least one selected.
                if selectedSpeeds.count > 1 { selectedSpeeds.remove(speed) }
            } else {
                selectedSpeeds.insert(speed)
            }
        }
    }

    // MARK: Order (only when >1 speed)

    private var orderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Order")
                .font(.inter(17, weight: .semibold))
                .foregroundColor(tokens.fg)
            PracticeSegmented(
                options: [("Random", PracticeOrder.random), ("Sequence", PracticeOrder.sequence)],
                selection: $order,
                tokens: tokens
            )
            Text(order == .random
                 ? "Each putt picks a random speed from your selection (weighted toward weaker speeds)."
                 : "Cycle through your speeds in order, low to high, repeating.")
                .font(.inter(15, weight: .medium))
                .foregroundColor(tokens.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .cardBackground(tokens)
    }

    // MARK: Putt count

    private var countCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Putts this session")
                .font(.inter(17, weight: .semibold))
                .foregroundColor(tokens.fg)

            // Preset chips + Infinite
            HStack(spacing: 8) {
                ForEach(PracticeViewModel.countPresets, id: \.self) { preset in
                    countChip(label: "\(preset)", selected: !isInfinite && puttCount == preset) {
                        isInfinite = false
                        puttCount = preset
                    }
                }
                countChip(label: "∞", selected: isInfinite) {
                    isInfinite = true
                }
            }

            // Custom stepper (disabled in infinite mode)
            HStack {
                Text(isInfinite ? "Open-ended" : "Custom")
                    .font(.inter(15, weight: .semibold))
                    .foregroundColor(isInfinite ? tokens.dim : tokens.sub)
                Spacer()
                if !isInfinite {
                    HStack(spacing: 16) {
                        stepButton("minus") {
                            puttCount = max(countBounds.lowerBound, puttCount - 1)
                        }
                        Text("\(puttCount)")
                            .font(.inter(22, weight: .heavy))
                            .foregroundColor(tokens.fg)
                            .frame(minWidth: 44)
                            .monospacedDigit()
                        stepButton("plus") {
                            puttCount = min(countBounds.upperBound, puttCount + 1)
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding()
        .cardBackground(tokens)
    }

    private func countChip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Text(label)
            .font(.inter(20, weight: .heavy))
            .foregroundColor(selected ? .white : tokens.fg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? tokens.zone : tokens.subtle)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeOut(duration: 0.12)) { action() } }
    }

    private func stepButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(tokens.fg)
                .frame(width: 40, height: 40)
                .background(tokens.subtle)
                .clipShape(Circle())
        }
    }
}

// MARK: - Active (ZERO-TOUCH — no controls between putts)
//
// Composed like the Sport live views (SportLiveContainer): header → pass strip (PUTTS LEFT/HIT +
// IN ZONE + tach bars) → chromeless hero (giant target + glide-down LAST PUTT) → end button, with
// the same edge-flash on each putt. Make % lives top-right of the hero target number.

struct ActivePracticeView: View {
    @EnvironmentObject var practiceViewModel: PracticeViewModel

    var body: some View {
        // Hand off to a session-observing child so the WHOLE live view (pass strip + tachs
        // included) re-renders the instant a putt lands. ActivePracticeView only observes the
        // view model, which does NOT republish per putt — observing the session here is what
        // keeps the tachs in lockstep with the hero.
        if let session = practiceViewModel.session {
            ActiveSessionContent(session: session)
        }
    }
}

private struct ActiveSessionContent: View {
    @ObservedObject var session: PracticeSession
    @EnvironmentObject var practiceViewModel: PracticeViewModel
    @State private var showEndAlert = false

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var tokens: SportTokens { practiceTokens(themeRaw, colorScheme) }

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                SportPassStrip(
                    config: .practice(total: session.targetCount,
                                      puttsTaken: session.puttsTaken,
                                      inZone: session.puttsMade),
                    tokens: tokens,
                    puttHistory: session.puttRecords,
                    totalPutts: session.targetCount ?? max(20, session.puttsTaken),
                    target: session.currentTarget,
                    tolerance: SpeedZone.getZone(for: session.currentTarget).tolerance,
                    isMultiSpeed: session.isMultiSpeed
                )

                PracticeHeroCard(session: session, tokens: tokens)
                    .frame(maxHeight: .infinity)

                SportEndButton(tokens: tokens, showAlert: $showEndAlert, title: "END SESSION")
                    .padding(.horizontal, 22)
                    .padding(.top, 4)
                    .padding(.bottom, 22)
            }

            SportEdgeFlash(
                lastPuttID: session.puttRecords.count,
                inZone: session.puttRecords.last?.isInZone
            )
        }
        .alert("End session?", isPresented: $showEndAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { practiceViewModel.endSession() }
        } message: {
            Text("Your putts so far are saved to your stats.")
        }
    }

    // Lightweight header: pulsing dot + title + speed summary + progress + close
    private var header: some View {
        HStack(spacing: fs(10)) {
            SportPulsingDot(color: tokens.zone)
            VStack(alignment: .leading, spacing: 2) {
                Text("FREE PRACTICE")
                    .font(.inter(fs(14), weight: .heavy))
                    .tracking(fs(14) * 0.12)
                    .foregroundColor(tokens.fg)
                Text(speedSummary)
                    .font(.inter(fs(12), weight: .semibold))
                    .foregroundColor(tokens.sub)
            }
            Spacer()
            if let progress = progressText {
                Text(progress)
                    .font(.inter(fs(18), weight: .heavy))
                    .foregroundColor(tokens.sub)
                    .padding(.trailing, fs(8))
            }
            Button { showEndAlert = true } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: fs(26)))
                    .foregroundColor(tokens.sub)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var speedSummary: String {
        let speeds = session.speeds.map { "\($0)" }.joined(separator: " · ")
        let mode = session.isMultiSpeed ? (session.order == .random ? "RANDOM" : "SEQUENCE") : "SINGLE"
        return "\(speeds) MPH · \(mode)"
    }

    private var progressText: String? {
        if let total = session.targetCount { return "\(min(session.puttsTaken + 1, total)) / \(total)" }
        return nil
    }
}

// MARK: - Practice hero (copy of SportHeroCard, adapted to PracticeSession)
//
// Same chromeless giant target + glide-down LAST PUTT banner as the Sport live views, with two
// deltas: the TARGET number never shrinks (no minimumScaleFactor), and the running MAKE % is
// overlaid top-right of the target.

private enum PracticeHeroPhase: Equatable { case idle, showing, settled }

struct PracticeHeroCard: View {
    @ObservedObject var session: PracticeSession
    let tokens: SportTokens

    @Namespace private var heroNS
    @State private var phase: PracticeHeroPhase = .idle
    @State private var capturedPutt: PuttResult? = nil
    @State private var chipVisible = false
    @State private var animTask: Task<Void, Never>? = nil

    private var displayTarget: Int { session.currentTarget }

    // MARK: Animation trigger (mirrors SportHeroCard.onNewPutt)

    private func onNewPutt(_ putt: PuttResult) {
        animTask?.cancel()
        chipVisible = false
        capturedPutt = putt
        phase = .showing

        animTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { phase = .settled }
            }
            try? await Task.sleep(nanoseconds: 620_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { chipVisible = true }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Bias the target slightly below centre so it clears the make% chip up top.
            Spacer(minLength: fs(56))
            centerNumber
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            lastPuttSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tokens.bg)
        .overlay(alignment: .topTrailing) { makeChip }
        .onChange(of: session.puttRecords.count) { _, count in
            guard count > 0, let p = session.puttRecords.last else { return }
            onNewPutt(p)
        }
    }

    // Make % — top-right of the target number
    private var makeChip: some View {
        VStack(alignment: .trailing, spacing: fs(2)) {
            Text("\(session.makePercent)%")
                .font(.inter(fs(52)))
                .foregroundColor(tokens.fg)
                .monospacedDigit()
            Text("MAKE %")
                .font(.inter(fs(16), weight: .heavy))
                .tracking(fs(16) * 0.14)
                .foregroundColor(tokens.sub)
        }
        .padding(.trailing, 22)
        .padding(.top, 8)
    }

    // MARK: - Centre number

    @ViewBuilder
    private var centerNumber: some View {
        ZStack {
            // TARGET (idle + settled) — never shrinks (no minimumScaleFactor).
            let tStr = "\(displayTarget)"
            let tFont: CGFloat = tStr.count >= 2 ? fs(150) : fs(200)
            VStack(spacing: fs(8)) {
                Text(tStr)
                    .font(.inter(tFont))
                    .foregroundColor(tokens.fg)
                    .lineLimit(1)
                    .monospacedDigit()
                unitRow(label: "TARGET", unitColor: tokens.fg)
            }
            .opacity(phase == .showing ? 0 : 1)

            // PUTT (showing; number glides to readout on settle).
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

    // MARK: - Last putt section (glide target + fade-in delta)

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

// MARK: - Complete (taps OK — session is over)

struct PracticeCompleteView: View {
    @EnvironmentObject var practiceViewModel: PracticeViewModel
    @Environment(\.dismiss) var dismiss

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var tokens: SportTokens { practiceTokens(themeRaw, colorScheme) }

    private var session: PracticeSession? { practiceViewModel.session }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(tokens.zone.opacity(0.15))
                        .frame(width: 110, height: 110)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(tokens.zone)
                }
                .padding(.top, 16)

                Text("Session Complete")
                    .font(.inter(30))
                    .foregroundColor(tokens.fg)

                if let session = session {
                    // Headline score
                    VStack(spacing: 6) {
                        Text("\(session.puttsMade) / \(session.puttsTaken)")
                            .font(.inter(80))
                            .foregroundColor(tokens.fg)
                        Text("made · \(session.makePercent)%")
                            .font(.inter(17, weight: .semibold))
                            .foregroundColor(tokens.sub)
                        Text(String(format: "avg miss %.1f MPH", session.averageDeviation))
                            .font(.inter(15, weight: .medium))
                            .foregroundColor(tokens.sub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .cardBackground(tokens)

                    // Per-putt breakdown
                    if !session.attempts.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(session.attempts) { attempt in
                                HStack {
                                    Text("\(attempt.targetSpeed) MPH")
                                        .font(.inter(17, weight: .bold))
                                        .foregroundColor(tokens.fg)
                                        .frame(width: 90, alignment: .leading)

                                    Image(systemName: "arrow.right")
                                        .font(.inter(12, weight: .medium))
                                        .foregroundColor(tokens.sub)

                                    Text(attempt.actualSpeed.toSpeedString())
                                        .font(.inter(17, weight: .bold))
                                        .foregroundColor(attempt.isInZone ? tokens.zone : tokens.miss)

                                    Spacer()

                                    Text(attempt.isInZone ? "Made" : (attempt.tooFirm ? "Firm" : "Soft"))
                                        .font(.inter(15, weight: .medium))
                                        .foregroundColor(tokens.sub)

                                    Image(systemName: attempt.isInZone ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(attempt.isInZone ? tokens.zone : tokens.miss)
                                }
                                .padding(.vertical, 10)
                                if attempt.id != session.attempts.last?.id {
                                    Rectangle().fill(tokens.subtle).frame(height: 1)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .cardBackground(tokens)
                    }
                }

                VStack(spacing: 12) {
                    Button {
                        practiceViewModel.playAgain()
                    } label: {
                        Text("Again")
                            .font(.inter(20, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(tokens.zone)
                            .cornerRadius(14)
                    }
                    Button {
                        practiceViewModel.endSession()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.inter(20, weight: .heavy))
                            .foregroundColor(tokens.fg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(tokens.subtle, lineWidth: 1.5))
                    }
                }
            }
            .padding()
            .adaptiveContentFrame(maxWidth: 680)
        }
        .background(tokens.bg.ignoresSafeArea())
    }
}

// MARK: - Segmented control

/// Token-themed segmented picker (matches the Recall start screen's control).
private struct PracticeSegmented<T: Hashable>: View {
    let options: [(label: String, value: T)]
    @Binding var selection: T
    let tokens: SportTokens

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { opt in
                let isSel = opt.value == selection
                Text(opt.label)
                    .font(.inter(17, weight: .heavy))
                    .foregroundColor(isSel ? tokens.zone : tokens.sub)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(isSel ? tokens.fg : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) { selection = opt.value }
                    }
            }
        }
        .padding(4)
        .background(tokens.subtle)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Card styling

private extension View {
    /// Token-themed card surface used across the practice start/complete screens.
    func cardBackground(_ tokens: SportTokens) -> some View {
        self
            .background(tokens.surface)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(tokens.subtle, lineWidth: 1))
    }
}
