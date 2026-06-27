//
//  RecallModeView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//
//  "Call the Speed" cold-recall mode + the Maintenance / Daily Tune-Up round.
//
//  USAGE CONTEXT: the phone lies face-up on the floor ~5–6 ft from the golfer. The active
//  loop is therefore ZERO-TOUCH — putts arrive over BLE and the screen auto-advances. The
//  golfer never bends down or taps between putts. All text is huge / high-contrast so it
//  reads in a glance at a shallow angle. Taps happen only at the start screen and the
//  end-of-round summary. Mirrors CombineModeView.
//
//  Styled with the current SportTokens design language (theme-aware colors + Inter type),
//  matching the SportLive live-session screens.
//

import SwiftUI
import UIKit
import AVFoundation

// MARK: - Theme helper

/// Resolves the current SportTokens from the shared liveViewTheme preference + colorScheme.
/// Mirrors the accessor used by every SportLive view so recall matches the live screens.
private func recallTokens(_ themeRaw: String, _ scheme: ColorScheme) -> SportTokens {
    SportTokens.make(dark: (LiveViewTheme(rawValue: themeRaw) ?? .light).resolvedDark(scheme: scheme))
}

// MARK: - Router

struct RecallModeView: View {
    @EnvironmentObject var recallViewModel: RecallViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var tokens: SportTokens { recallTokens(themeRaw, colorScheme) }

    @State private var lastRecordedSpeed: Float = 0.0

    var body: some View {
        ZStack {
            tokens.bg.ignoresSafeArea()

            if !recallViewModel.isActive || recallViewModel.round == nil {
                RecallStartView()
            } else if recallViewModel.phase == .complete {
                RecallCompleteView()
            } else {
                ActiveRecallView()
            }
        }
        .onChange(of: bluetoothService.currentSpeed) { _, newSpeed in
            // Only register a putt while actively prompting; the VM also guards this.
            guard recallViewModel.isActive, recallViewModel.phase == .prompting else { return }
            if newSpeed > 0 && newSpeed != lastRecordedSpeed {
                recallViewModel.recordPutt(newSpeed)
                lastRecordedSpeed = newSpeed
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }
}

// MARK: - Start (taps OK — golfer is at the phone)

struct RecallStartView: View {
    @EnvironmentObject var recallViewModel: RecallViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    @Environment(\.dismiss) var dismiss

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var tokens: SportTokens { recallTokens(themeRaw, colorScheme) }

    @State private var feedbackMode: RecallFeedbackMode = .blind
    @State private var roundLength: Int = RecallViewModel.defaultRoundLength
    @AppStorage("recallShowNumber") private var showNumber = false
    @AppStorage("recallVoiceIdentifier") private var voiceIdentifier = ""

    @AppStorage("hasSeenRecallTour") private var seenRecallTour = false
    @State private var recallTourIndex: Int? = nil
    private let recallTourSteps = TourCopy.recall

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    Image(systemName: "ear.badge.waveform")
                        .font(.system(size: 70))
                        .foregroundColor(tokens.zone)
                        .padding(.top, 8)

                    VStack(spacing: 8) {
                        Text("Call the Speed")
                            .font(.inter(34))
                            .foregroundColor(tokens.fg)
                        Text("Hit the number from feel — the live reading stays hidden until you've putted.")
                            .font(.inter(17, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundColor(tokens.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Best score
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Best")
                                .font(.inter(15, weight: .medium))
                                .foregroundColor(tokens.sub)
                            Text("\(recallViewModel.bestScore)%")
                                .font(.inter(34))
                                .foregroundColor(tokens.zone)
                        }
                        Spacer()
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 28))
                            .foregroundColor(recallViewModel.bestScore > 0 ? tokens.zone : tokens.subtle)
                    }
                    .padding()
                    .cardBackground(tokens)

                    // Speed range — only the speeds unlocked through Training are called.
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speed range")
                                .font(.inter(17, weight: .semibold))
                                .foregroundColor(tokens.fg)
                            Spacer()
                            Text(recallViewModel.speedRangeText)
                                .font(.inter(17, weight: .heavy))
                                .foregroundColor(tokens.zone)
                        }
                        Text("You're only called speeds you've unlocked in Training. The range grows as you pass gate tests.")
                            .font(.inter(15, weight: .medium))
                            .foregroundColor(tokens.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .cardBackground(tokens)
                    .coachmarkAnchor(0)
                    .id(0)

                    // Round length
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Putts this round")
                            .font(.inter(17, weight: .semibold))
                            .foregroundColor(tokens.fg)
                        RecallSegmented(
                            options: [("6", 6), ("9", 9), ("12", 12)],
                            selection: $roundLength,
                            tokens: tokens
                        )
                    }
                    .padding()
                    .cardBackground(tokens)
                    .coachmarkAnchor(1)
                    .id(1)

                    // Feedback mode
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Feedback")
                            .font(.inter(17, weight: .semibold))
                            .foregroundColor(tokens.fg)
                        RecallSegmented(
                            options: [("Blind", RecallFeedbackMode.blind),
                                      ("Coached", RecallFeedbackMode.coached)],
                            selection: $feedbackMode,
                            tokens: tokens
                        )
                        Text(feedbackMode == .coached
                             ? "See how each putt did right after you hit it."
                             : "No feedback until the end — pure recall. Tougher, best for transfer.")
                            .font(.inter(15, weight: .medium))
                            .foregroundColor(tokens.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .cardBackground(tokens)
                    .coachmarkAnchor(2)
                    .id(2)

                    // Show the number (voice is always on) + voice picker
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $showNumber) {
                            Text("Show the number")
                                .font(.inter(17, weight: .semibold))
                                .foregroundColor(tokens.fg)
                        }
                        .tint(tokens.zone)
                        Text("Off = voice-only: you'll hear the number but never see it. On = also flash it on screen.")
                            .font(.inter(15, weight: .medium))
                            .foregroundColor(tokens.sub)
                            .fixedSize(horizontal: false, vertical: true)

                        Rectangle().fill(tokens.subtle).frame(height: 1)
                        HStack(spacing: 12) {
                            Text("Voice")
                                .font(.inter(17, weight: .semibold))
                                .foregroundColor(tokens.fg)
                            Spacer()
                            Picker("Voice", selection: $voiceIdentifier) {
                                Text("Default").tag("")
                                ForEach(RecallSpeaker.englishVoices, id: \.identifier) { v in
                                    Text(voiceLabel(v)).tag(v.identifier)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(tokens.zone)
                            Button {
                                RecallSpeaker.shared.preview()
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(tokens.zone)
                            }
                        }
                    }
                    .padding()
                    .cardBackground(tokens)
                    .coachmarkAnchor(3)
                    .id(3)

                    Button {
                        if bluetoothService.isConnected {
                            recallViewModel.startRound(length: roundLength,
                                                       feedbackMode: feedbackMode,
                                                       voiceEnabled: true,
                                                       showNumber: showNumber)
                        }
                    } label: {
                        Text(bluetoothService.isConnected ? "Start" : "Connect Device First")
                            .font(.inter(20, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(tokens.zone.opacity(bluetoothService.isConnected ? 1 : 0.5))
                            .cornerRadius(14)
                    }
                    .disabled(!bluetoothService.isConnected)
                    .coachmarkAnchor(4)
                    .id(4)
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
            .onChange(of: recallTourIndex) { _, i in
                if let i { withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(i, anchor: .center) } }
            }
            }
        }
        .navigationViewStyle(.stack)
        .coachmarkTour(recallTourSteps, index: $recallTourIndex, style: .sport(tokens)) {
            seenRecallTour = true
            recallTourIndex = nil
        }
        .onAppear {
            if !seenRecallTour && recallTourIndex == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if !seenRecallTour { recallTourIndex = 0 }
                }
            }
        }
    }

    /// Readable menu label for a voice — name + region, plus an Enhanced/Premium marker so
    /// same-named voices (e.g. two "Samantha"s) are distinguishable.
    private func voiceLabel(_ v: AVSpeechSynthesisVoice) -> String {
        let region = Locale.current.localizedString(forLanguageCode: v.language) ?? v.language
        var label = "\(v.name) (\(region))"
        switch v.quality {
        case .premium:  label += " · Premium"
        case .enhanced: label += " · Enhanced"
        default:        break
        }
        return label
    }
}

// MARK: - Active (ZERO-TOUCH — no controls between putts)

struct ActiveRecallView: View {
    @EnvironmentObject var recallViewModel: RecallViewModel
    @State private var showEndAlert = false

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var tokens: SportTokens { recallTokens(themeRaw, colorScheme) }

    private var round: RecallRound? { recallViewModel.round }

    var body: some View {
        VStack(spacing: 0) {
            // Top strip: progress + a deliberate End (only non-auto control)
            HStack {
                if let round = round {
                    Text("\(min(round.currentPrompt + 1, round.roundLength)) / \(round.roundLength)")
                        .font(.inter(fs(26), weight: .heavy))
                        .foregroundColor(tokens.sub)
                }
                Spacer()
                Button {
                    showEndAlert = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: fs(28)))
                        .foregroundColor(tokens.sub)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            switch recallViewModel.phase {
            case .counting:
                countdownContent
            case .prompting:
                promptContent
            case .revealing:
                revealContent
            case .logged:
                loggedContent
            case .complete:
                EmptyView()
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(phaseBackground.ignoresSafeArea())
        .alert("End round?", isPresented: $showEndAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { recallViewModel.endRound() }
        } message: {
            Text("Your progress this round won't be saved to your best score.")
        }
    }

    // .counting — 3-2-1 "get ready" ring before the target is spoken/shown. Mirrors the
    // countdown ring in BlockTransitionView / BlockFailedView, themed with SportTokens.
    private var countdownContent: some View {
        VStack(spacing: fs(22)) {
            Text("GET READY")
                .font(.inter(fs(24), weight: .heavy))
                .foregroundColor(tokens.sub)
                .tracking(fs(24) * 0.18)
            ZStack {
                Circle()
                    .stroke(tokens.subtle, lineWidth: 6)
                    .frame(width: fs(160), height: fs(160))
                Circle()
                    .trim(from: 0, to: CGFloat(recallViewModel.countdown) / 3.0)
                    .stroke(tokens.zone, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: fs(160), height: fs(160))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.9), value: recallViewModel.countdown)
                Text("\(recallViewModel.countdown)")
                    .font(.inter(fs(84)))
                    .foregroundColor(tokens.fg)
            }
        }
    }

    // .prompting — target shown HUGE for ~1s (or never, in voice-only), then a putt cue
    private var promptContent: some View {
        VStack(spacing: 0) {
            ZStack {
                // Target number — visible briefly, hidden before the stroke
                VStack(spacing: fs(8)) {
                    Text("HIT")
                        .font(.inter(fs(34), weight: .heavy))
                        .foregroundColor(tokens.sub)
                    Text("\(round?.currentTarget ?? 0)")
                        .font(.inter(fs(170)))
                        .foregroundColor(tokens.fg)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("MPH")
                        .font(.inter(fs(36), weight: .heavy))
                        .foregroundColor(tokens.sub)
                }
                .opacity(recallViewModel.targetVisible ? 1 : 0)

                // Putt cue — appears once the number is hidden
                VStack(spacing: fs(12)) {
                    Image(systemName: "ear.badge.waveform")
                        .font(.system(size: fs(64)))
                        .foregroundColor(tokens.sub)
                    Text("PUTT NOW")
                        .font(.inter(fs(48), weight: .heavy))
                        .foregroundColor(tokens.fg)
                    Text("hit it from memory")
                        .font(.inter(fs(22), weight: .semibold))
                        .foregroundColor(tokens.dim)
                }
                .opacity(recallViewModel.targetVisible ? 0 : 1)
            }
            .animation(.easeInOut(duration: 0.3), value: recallViewModel.targetVisible)

            // Replay the spoken number (voice mode only)
            if recallViewModel.voiceEnabled {
                Button {
                    recallViewModel.repeatVoice()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: fs(10)) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: fs(24)))
                        Text("REPEAT")
                            .font(.inter(fs(22), weight: .heavy))
                            .tracking(fs(22) * 0.12)
                    }
                    .foregroundColor(tokens.fg)
                    .padding(.vertical, fs(14))
                    .padding(.horizontal, fs(32))
                    .overlay(Capsule().stroke(tokens.subtle, lineWidth: 1.5))
                }
                .padding(.top, fs(36))
            }
        }
    }

    // .revealing (coached) — actual speed + verdict, large
    @ViewBuilder
    private var revealContent: some View {
        if let attempt = round?.lastAttempt {
            VStack(spacing: fs(6)) {
                Text(attempt.actualSpeed.toSpeedString())
                    .font(.inter(fs(150)))
                    .foregroundColor(attempt.isInZone ? tokens.zone : tokens.miss)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Image(systemName: attempt.isInZone ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: fs(56)))
                    .foregroundColor(attempt.isInZone ? tokens.zone : tokens.miss)

                Text(verdict(for: attempt))
                    .font(.inter(fs(44), weight: .heavy))
                    .foregroundColor(attempt.isInZone ? tokens.zone : tokens.miss)

                Text("target \(attempt.targetSpeed) MPH")
                    .font(.inter(fs(24), weight: .bold))
                    .foregroundColor(tokens.sub)
                    .padding(.top, fs(4))
            }
        }
    }

    // .logged (blind) — confirmation only, no result
    private var loggedContent: some View {
        VStack(spacing: fs(10)) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: fs(120)))
                .foregroundColor(tokens.zone)
            Text("LOGGED")
                .font(.inter(fs(48), weight: .heavy))
                .foregroundColor(tokens.fg)
            Text("\(round?.promptsRemaining ?? 0) to go")
                .font(.inter(fs(28), weight: .bold))
                .foregroundColor(tokens.sub)
        }
    }

    private var phaseBackground: Color {
        switch recallViewModel.phase {
        case .revealing:
            if let a = round?.lastAttempt {
                return (a.isInZone ? tokens.zone : tokens.miss).opacity(0.08)
            }
            return tokens.bg
        default:
            return tokens.bg
        }
    }

    private func verdict(for attempt: RecallAttempt) -> String {
        if attempt.isInZone { return "IN THE ZONE" }
        return attempt.tooFirm ? "TOO FIRM" : "TOO SOFT"
    }
}

// MARK: - Complete (taps OK — round is over)

struct RecallCompleteView: View {
    @EnvironmentObject var recallViewModel: RecallViewModel
    @Environment(\.dismiss) var dismiss

    @AppStorage("liveViewTheme") private var themeRaw: String = LiveViewTheme.light.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var tokens: SportTokens { recallTokens(themeRaw, colorScheme) }

    private var round: RecallRound? { recallViewModel.round }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                let isBest = recallViewModel.isNewBest

                ZStack {
                    Circle()
                        .fill(tokens.zone.opacity(0.15))
                        .frame(width: 110, height: 110)
                    Image(systemName: isBest ? "trophy.fill" : "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(tokens.zone)
                }
                .padding(.top, 16)

                Text(isBest ? "New Best!" : "Round Complete")
                    .font(.inter(30))
                    .foregroundColor(isBest ? tokens.zone : tokens.fg)

                if let round = round {
                    // Headline score
                    VStack(spacing: 6) {
                        Text("\(round.inZoneCount) / \(round.roundLength)")
                            .font(.inter(80))
                            .foregroundColor(tokens.fg)
                        Text("in the zone · \(round.accuracyPercent)%")
                            .font(.inter(17, weight: .semibold))
                            .foregroundColor(tokens.sub)
                        Text(String(format: "avg miss %.1f MPH", round.averageDeviation))
                            .font(.inter(15, weight: .medium))
                            .foregroundColor(tokens.sub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .cardBackground(tokens)

                    // Per-putt breakdown
                    VStack(spacing: 0) {
                        ForEach(round.attempts) { attempt in
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

                                Text(attempt.isInZone ? "In zone" : (attempt.tooFirm ? "Firm" : "Soft"))
                                    .font(.inter(15, weight: .medium))
                                    .foregroundColor(tokens.sub)

                                Image(systemName: attempt.isInZone ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(attempt.isInZone ? tokens.zone : tokens.miss)
                            }
                            .padding(.vertical, 10)
                            if attempt.id != round.attempts.last?.id {
                                Rectangle().fill(tokens.subtle).frame(height: 1)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .cardBackground(tokens)
                }

                VStack(spacing: 12) {
                    Button {
                        recallViewModel.playAgain()
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
                        recallViewModel.endRound()
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

/// Token-themed segmented picker. The native `.segmented` style can't be recolored, and its
/// gray-on-gray selected chip was hard to read — so the selected chip is filled with `tokens.fg`
/// (black in light mode) and its label is `tokens.zone` (green) for strong contrast.
private struct RecallSegmented<T: Hashable>: View {
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
    /// Token-themed card surface used across the recall start/complete screens.
    func cardBackground(_ tokens: SportTokens) -> some View {
        self
            .background(tokens.surface)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(tokens.subtle, lineWidth: 1))
    }
}
