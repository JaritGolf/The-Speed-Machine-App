//
//  RecallViewModel.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//
//  Drives the "Call the Speed" cold-recall mode and the Maintenance / Daily Tune-Up round
//  (a recall round pre-seeded with the speeds most in need of work). The per-putt loop is
//  100% BLE-driven and auto-advancing — no taps between putts — so it works with the phone
//  flat on the floor 5–6 ft away. Mirrors CombineViewModel.
//

import Foundation
import Combine
import AVFoundation

/// What the active screen is showing right now.
enum RecallPhase {
    case counting    // 3-2-1 "get ready" countdown before the target is spoken/shown
    case prompting   // target shown big, live reading hidden, awaiting the putt
    case revealing   // coached: showing the result of the putt just made
    case logged      // blind: brief "logged" confirmation, no result shown
    case complete    // round finished → summary
}

class RecallViewModel: ObservableObject {
    @Published var round: RecallRound?
    @Published var isActive = false
    @Published var phase: RecallPhase = .prompting
    @Published var bestScore: Int = 0   // best in-zone percentage

    /// Whether the giant target number is currently on screen. Driven by `presentPrompt()`:
    /// it shows on a new prompt, then hides after 1s (so the putt is from recall), or never
    /// shows at all in voice-only mode (`showNumber == false`).
    @Published var targetVisible = true

    /// Seconds left on the "get ready" countdown that precedes each prompt (3 → 1).
    @Published var countdown = 3
    private let countdownSeconds = 3
    private var countdownToken = 0

    /// Per-round settings chosen on the start screen.
    private(set) var voiceEnabled = true   // speak each target number aloud
    private(set) var showNumber = false    // display the number (off = voice-only)

    private let statsService = StatsService.shared
    private let adaptiveEngine = AdaptiveSpeedEngine.shared

    /// Highest speed the player has reached in Training (max `availableSpeeds` of the highest
    /// completed track). Recall only asks for speeds up to this, so it grows as training
    /// progresses and never previews untrained speeds. (Combine uses its own gate ceiling.)
    var maxTrainedSpeed: Int {
        let completedTrack = Int(DataService.shared.userProgress.currentDay) - 1   // linear/gated program
        guard completedTrack >= 1, let program = TrainingProgramLoader.shared.program else {
            return Self.goalRange.lowerBound
        }
        let track = min(completedTrack, program.days.count)
        let reached = program.days.first(where: { $0.day == track })?.availableSpeeds.max()
            ?? Self.goalRange.lowerBound
        return min(reached, Self.goalRange.upperBound)
    }

    /// Display string for the setup screen, e.g. "3–9 MPH".
    var speedRangeText: String {
        "\(Self.goalRange.lowerBound)–\(maxTrainedSpeed) MPH"
    }

    private var roundStartTime: Date?
    /// Bumped every time we schedule an auto-advance so stale timers are ignored.
    private var advanceToken = 0
    /// Bumped on each new prompt so a stale 1s hide-timer can't blank the next prompt.
    private var promptToken = 0

    // Defaults
    static let defaultRoundLength = 9
    static let goalRange = 3...15
    private let revealDuration: TimeInterval = 2.5
    private let loggedDuration: TimeInterval = 1.0

    private let bestScoreKey = "recallBestAccuracyPercent"

    // Remember the last round's shape so "Again" repeats the same kind.
    private var lastWasMaintenance = false
    private var lastLength = defaultRoundLength
    private var lastRange = goalRange
    private var lastFeedbackMode: RecallFeedbackMode = .coached
    private var lastVoiceEnabled = true
    private var lastShowNumber = false

    init() {
        bestScore = UserDefaults.standard.integer(forKey: bestScoreKey)
    }

    // MARK: - Start

    /// A standard cold-recall round drawing from a contiguous speed range (default 3–15),
    /// adaptively weighted toward weak speeds.
    func startRound(length: Int = defaultRoundLength,
                    range: ClosedRange<Int> = goalRange,
                    feedbackMode: RecallFeedbackMode,
                    voiceEnabled: Bool = true,
                    showNumber: Bool = false) {
        // Only draw from speeds the player has actually reached in Training.
        let ceiling = maxTrainedSpeed
        let pool = Array(range).filter { $0 <= ceiling }
        let safePool = pool.isEmpty ? [range.lowerBound] : pool
        let targets = adaptiveEngine.weightedRandomSpeeds(from: safePool, count: length)
        lastWasMaintenance = false
        lastLength = length
        lastRange = range
        lastFeedbackMode = feedbackMode
        begin(targets: targets, feedbackMode: feedbackMode, isMaintenance: false,
              voiceEnabled: voiceEnabled, showNumber: showNumber)
    }

    /// Daily Tune-Up: a recall round concentrated on the speeds most in need of work
    /// (`StatsService.maintenanceFocusSpeeds`), falling back to the full goal range if there
    /// isn't enough practice history yet.
    func startMaintenanceRound(length: Int = defaultRoundLength,
                               feedbackMode: RecallFeedbackMode = .coached,
                               voiceEnabled: Bool = true,
                               showNumber: Bool = false) {
        // Cap to reached speeds too (a no-op once the program is complete, but keeps the rule in one place).
        let ceiling = maxTrainedSpeed
        let focus = statsService.maintenanceFocusSpeeds.filter { $0 <= ceiling }
        let pool = focus.isEmpty ? Array(Self.goalRange).filter { $0 <= ceiling } : focus
        let targets = adaptiveEngine.weightedRandomSpeeds(from: pool, count: length)
        lastWasMaintenance = true
        lastLength = length
        lastFeedbackMode = feedbackMode
        begin(targets: targets, feedbackMode: feedbackMode, isMaintenance: true,
              voiceEnabled: voiceEnabled, showNumber: showNumber)
    }

    /// Repeat the same kind of round just played (the "Again" button).
    func playAgain() {
        if lastWasMaintenance {
            startMaintenanceRound(length: lastLength, feedbackMode: lastFeedbackMode,
                                  voiceEnabled: lastVoiceEnabled, showNumber: lastShowNumber)
        } else {
            startRound(length: lastLength, range: lastRange, feedbackMode: lastFeedbackMode,
                       voiceEnabled: lastVoiceEnabled, showNumber: lastShowNumber)
        }
    }

    private func begin(targets: [Int], feedbackMode: RecallFeedbackMode, isMaintenance: Bool,
                       voiceEnabled: Bool, showNumber: Bool) {
        guard !targets.isEmpty else { return }
        // Voice-only requires voice; with voice off the number always shows (then hides at 1s).
        self.voiceEnabled = voiceEnabled
        self.showNumber = voiceEnabled ? showNumber : true
        lastVoiceEnabled = voiceEnabled
        lastShowNumber = showNumber
        round = RecallRound(targets: targets, feedbackMode: feedbackMode, isMaintenance: isMaintenance)
        roundStartTime = Date()
        isActive = true
        advanceToken += 1
        startCountdown()
    }

    /// Runs a 3-2-1 "get ready" countdown, then reveals/speaks the target. Fires on session
    /// start and before every subsequent prompt so the golfer can set up first.
    private func startCountdown() {
        phase = .counting
        countdown = countdownSeconds
        countdownToken += 1
        tickCountdown(token: countdownToken)
    }

    private func tickCountdown(token: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.isActive,
                  self.phase == .counting, self.countdownToken == token else { return }
            self.countdown -= 1
            if self.countdown <= 0 {
                self.presentPrompt()
            } else {
                self.tickCountdown(token: token)
            }
        }
    }

    /// Shows (and optionally speaks) the current target. The number auto-hides after 1s so the
    /// golfer putts from recall; in voice-only mode it never appears.
    private func presentPrompt() {
        phase = .prompting
        promptToken += 1
        let token = promptToken
        if voiceEnabled { RecallSpeaker.shared.speak(round?.currentTarget ?? 0) }
        if showNumber {
            targetVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self, self.isActive, self.phase == .prompting,
                      self.promptToken == token else { return }
                self.targetVisible = false
            }
        } else {
            targetVisible = false
        }
    }

    /// Re-speak the current target on demand (the in-session REPEAT button). Audio only — it
    /// does not re-show the number or touch the 1s hide timer, so it works in voice-only too.
    func repeatVoice() {
        guard isActive, phase == .prompting, voiceEnabled else { return }
        RecallSpeaker.shared.speak(round?.currentTarget ?? 0)
    }

    // MARK: - Putt input (BLE-driven, auto-advancing)

    func recordPutt(_ speed: Float) {
        // Only accept a putt while actively prompting — ignores BLE chatter during the
        // reveal/logged window so a single stroke is never counted twice.
        guard isActive, phase == .prompting, let round = round, speed > 0 else { return }

        round.recordAttempt(actualSpeed: speed)

        // Every recall putt feeds lifetime stats, exactly like Combine does.
        if let attempt = round.lastAttempt {
            let tolerance = SpeedZone.getZone(for: attempt.targetSpeed).tolerance
            statsService.recordPutt(targetSpeed: attempt.targetSpeed,
                                    actualSpeed: attempt.actualSpeed,
                                    tolerance: tolerance)
        }

        if round.isComplete {
            completeRound()
            return
        }

        // Auto-advance to the next prompt with no tap.
        advanceToken += 1
        let token = advanceToken
        if round.feedbackMode == .coached {
            phase = .revealing
            scheduleAdvance(after: revealDuration, token: token)
        } else {
            phase = .logged
            scheduleAdvance(after: loggedDuration, token: token)
        }
    }

    private func scheduleAdvance(after delay: TimeInterval, token: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isActive, self.advanceToken == token else { return }
            if self.phase == .revealing || self.phase == .logged {
                self.startCountdown()
            }
        }
    }

    // MARK: - Complete / end

    private func completeRound() {
        guard let round = round else { return }
        phase = .complete

        if round.accuracyPercent > bestScore {
            bestScore = round.accuracyPercent
            UserDefaults.standard.set(bestScore, forKey: bestScoreKey)
        }

        if let start = roundStartTime {
            statsService.addPracticeTime(seconds: Date().timeIntervalSince(start))
        }
    }

    /// End early or dismiss from the summary.
    func endRound() {
        // Bank practice time for an early exit too.
        if isActive, phase != .complete, let start = roundStartTime {
            statsService.addPracticeTime(seconds: Date().timeIntervalSince(start))
        }
        isActive = false
        round = nil
        roundStartTime = nil
        phase = .prompting
        targetVisible = true
        advanceToken += 1
    }

    var isNewBest: Bool {
        guard let round = round else { return false }
        return round.accuracyPercent >= bestScore && round.accuracyPercent > 0
    }
}

// MARK: - Voice callout

/// Speaks a target number aloud for recall mode's voice / voice-only modes. The app has no
/// other audio, so this owns a minimal AVSpeechSynthesizer and a `.playback` session (audible
/// even with the ringer silenced, ducking other audio). Colocated here because the build target
/// does not auto-compile new standalone files.
final class RecallSpeaker {
    static let shared = RecallSpeaker()
    static let voiceKey = "recallVoiceIdentifier"

    private let synth = AVSpeechSynthesizer()

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
    }

    /// English voices installed on the device (incl. enhanced/premium ones the user has
    /// downloaded), sorted by name — the choices offered in the recall voice picker.
    static var englishVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
    }

    func speak(_ number: Int) {
        try? AVAudioSession.sharedInstance().setActive(true)
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "\(number)")
        if let id = UserDefaults.standard.string(forKey: Self.voiceKey), !id.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(utterance)
    }

    /// Audition the currently selected voice from the settings UI.
    func preview() { speak(8) }
}
