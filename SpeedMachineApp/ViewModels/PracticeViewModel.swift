//
//  PracticeViewModel.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//
//  Drives Free Practice: a self-paced blocked-practice block on a chosen speed (or set of
//  speeds) for a fixed count or open-ended. Like Recall, the per-putt loop is BLE-driven and
//  auto-advancing (phone flat on the floor, no taps between putts), but here every putt simply
//  feeds the running tally — there is no pass gate. Each putt feeds lifetime stats and the
//  session is saved to history, exactly like Recall and Combine.
//

import Foundation
import Combine

/// What the active screen is showing right now.
enum PracticePhase {
    case active      // live block — the hero animates each putt internally
    case complete    // session finished → summary
}

class PracticeViewModel: ObservableObject {
    @Published var session: PracticeSession?
    @Published var isActive = false
    @Published var phase: PracticePhase = .active

    private let statsService = StatsService.shared
    private let dataService = DataService.shared

    /// Core Data backing for history (mirrors how Combine/Training persist sessions).
    private var sessionData: SessionData?

    private var roundStartTime: Date?
    /// Bumped on each putt so a stale completion timer can't fire after an early end / restart.
    private var completeToken = 0

    /// Lets the final putt's LAST PUTT banner animate before the summary appears
    /// (matches the completion delay used by the training live view).
    private let completeDelay: TimeInterval = 2.5

    // Defaults / config bounds shared with the start screen.
    static let speedRange = 3...15
    static let defaultSpeeds = [8]
    static let countPresets = [10, 20, 30, 50]
    static let defaultCount = 20

    // Remember the last session's shape so "Again" repeats it.
    private var lastSpeeds: [Int] = defaultSpeeds
    private var lastOrder: PracticeOrder = .random
    private var lastCount: Int? = defaultCount

    // MARK: - Start

    /// Begin a session. `count == nil` runs open-ended until the user taps End.
    func start(speeds: [Int], order: PracticeOrder, count: Int?) {
        let clean = speeds.isEmpty ? Self.defaultSpeeds : speeds.sorted()
        lastSpeeds = clean
        lastOrder = order
        lastCount = count

        session = PracticeSession(speeds: clean, order: order, targetCount: count)
        sessionData = dataService.createSession(dayNumber: 0,
                                                blockId: "free-practice",
                                                targetPutts: count ?? 0)
        roundStartTime = Date()
        isActive = true
        phase = .active
        completeToken += 1
    }

    /// Repeat the same session just played (the "Again" button).
    func playAgain() {
        start(speeds: lastSpeeds, order: lastOrder, count: lastCount)
    }

    // MARK: - Putt input (BLE-driven, auto-advancing)

    func recordPutt(_ speed: Float) {
        // Ignore putts once the session is complete; the BLE onChange dedupes identical speeds.
        guard isActive, phase == .active, let session = session, speed > 0 else { return }

        let target = session.currentTarget
        let tolerance = SpeedZone.getZone(for: target).tolerance
        // Classify via SpeedMath (integer tenths) — a raw Float compare misclassifies boundary
        // putts like 10.6 at 10 ±0.6. See SpeedMath in Constants.swift.
        let isInZone = SpeedMath.isInZone(actual: speed, target: target, tolerance: tolerance)

        let attempt = session.recordAttempt(actualSpeed: speed, isInZone: isInZone)

        // Feed lifetime stats + persist the putt to history.
        statsService.recordPutt(targetSpeed: target,
                                actualSpeed: attempt.actualSpeed,
                                tolerance: tolerance)
        if let sessionData = sessionData {
            dataService.recordPutt(session: sessionData,
                                   targetSpeed: Float(target),
                                   actualSpeed: attempt.actualSpeed,
                                   tolerance: tolerance,
                                   isOnTarget: isInZone)
        }

        // `recordAttempt` already advanced `currentTarget`; the hero covers the swap with its
        // own putt animation. For a finite session, let the final putt animate, then summarize.
        if session.isComplete {
            completeToken += 1
            let token = completeToken
            DispatchQueue.main.asyncAfter(deadline: .now() + completeDelay) { [weak self] in
                guard let self = self, self.isActive, self.completeToken == token,
                      self.phase == .active else { return }
                self.complete()
            }
        }
    }

    // MARK: - Complete / end

    private func complete() {
        phase = .complete
        persistAndBank(markComplete: true)
    }

    /// End early (the in-session End button) or dismiss from the summary.
    func endSession() {
        if isActive, phase != .complete {
            // Save what was completed so the early-ended session still lands in history.
            persistAndBank(markComplete: true)
        }
        isActive = false
        session = nil
        sessionData = nil
        roundStartTime = nil
        phase = .active
        completeToken += 1   // invalidate any pending completion timer
    }

    private func persistAndBank(markComplete: Bool) {
        if let sessionData = sessionData, let session = session {
            dataService.updateSession(sessionData,
                                      completedPutts: session.puttsTaken,
                                      onTargetPutts: session.puttsMade,
                                      isComplete: markComplete)
        }
        if let start = roundStartTime {
            statsService.addPracticeTime(seconds: Date().timeIntervalSince(start))
            roundStartTime = nil
        }
    }
}
