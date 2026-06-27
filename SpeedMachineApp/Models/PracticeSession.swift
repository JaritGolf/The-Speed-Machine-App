//
//  PracticeSession.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//
//  Free Practice — pick one or more target speeds and a putt count (or go open-ended),
//  then grind a blocked-practice block. Unlike a structured training block there is no
//  "putts needed" pass gate: the screen just tracks putts taken / left, putts made, and a
//  running make %. Mirrors the shape of RecallRound.
//

import Foundation
import Combine

/// How the selected speeds are distributed across the session.
enum PracticeOrder: String {
    case random     // weighted-random pick each putt (toward weak speeds)
    case sequence   // cycle the chosen speeds in order, repeating
}

struct PracticeAttempt: Identifiable {
    let id = UUID()
    let puttNumber: Int
    let targetSpeed: Int
    let actualSpeed: Float
    let isInZone: Bool
    let deviation: Float        // absolute MPH from target
    let signedDeviation: Float  // actual − target (> 0 = too firm / fast)

    var tooFirm: Bool { signedDeviation > 0 }
}

class PracticeSession: ObservableObject {
    @Published var attempts: [PracticeAttempt] = []
    /// The speed to hit next. Computed up front and re-derived after every putt.
    @Published var currentTarget: Int

    let speeds: [Int]
    let order: PracticeOrder
    /// Total putts in the session, or `nil` for an open-ended / infinite block.
    let targetCount: Int?

    private let adaptiveEngine = AdaptiveSpeedEngine.shared

    init(speeds: [Int], order: PracticeOrder, targetCount: Int?) {
        // Defensive: never start empty.
        let clean = speeds.isEmpty ? [8] : speeds
        self.speeds = clean
        self.order = order
        self.targetCount = targetCount
        self.currentTarget = clean.first ?? 8
        // Random mode opens on a weighted pick rather than always the first chip.
        if order == .random {
            self.currentTarget = adaptiveEngine.weightedRandomSpeeds(from: clean, count: 1).first ?? clean[0]
        }
    }

    // MARK: - Derived counters

    var isInfinite: Bool { targetCount == nil }

    /// True once more than one target speed is in play — drives the labeled (numbered) tach
    /// strip, exactly like `SessionProgress.isMultiSpeed`.
    var isMultiSpeed: Bool { speeds.count > 1 }

    /// Attempts mapped into the shared `PuttResult` shape so the existing Sport live-view
    /// widgets (`SportPassStrip` / `TachBars`) can render practice putts unchanged.
    var puttRecords: [PuttResult] {
        attempts.map { a in
            PuttResult(
                puttNumber: a.puttNumber,
                targetSpeed: Float(a.targetSpeed),
                actualSpeed: a.actualSpeed,
                tolerance: SpeedZone.getZone(for: a.targetSpeed).tolerance,
                isOnTarget: a.isInZone,
                isInZone: a.isInZone,
                difference: a.deviation
            )
        }
    }

    var puttsTaken: Int { attempts.count }

    var puttsMade: Int { attempts.filter { $0.isInZone }.count }

    /// Putts remaining for a finite session; `nil` when open-ended.
    var puttsLeft: Int? { targetCount.map { max(0, $0 - puttsTaken) } }

    /// Make rate as a whole-number percent.
    var makePercent: Int {
        guard !attempts.isEmpty else { return 0 }
        return Int((Double(puttsMade) / Double(attempts.count) * 100).rounded())
    }

    var isComplete: Bool {
        guard let target = targetCount else { return false }
        return puttsTaken >= target
    }

    var lastAttempt: PracticeAttempt? { attempts.last }

    var averageDeviation: Float {
        guard !attempts.isEmpty else { return 0 }
        return attempts.reduce(0) { $0 + $1.deviation } / Float(attempts.count)
    }

    // MARK: - Recording

    /// Record a putt against the current target, then advance `currentTarget` for the next one.
    /// Classification (`isInZone`) is decided by the view model via `SpeedMath` — kept out of
    /// this model so all make/miss math stays in one place (see SpeedMath in Constants.swift).
    @discardableResult
    func recordAttempt(actualSpeed: Float, isInZone: Bool) -> PracticeAttempt {
        let target = currentTarget
        // Round to 1 decimal to match live display precision (same as TrainingViewModel).
        let rounded = (actualSpeed * 10).rounded() / 10
        let signed = rounded - Float(target)

        let attempt = PracticeAttempt(
            puttNumber: attempts.count + 1,
            targetSpeed: target,
            actualSpeed: rounded,
            isInZone: isInZone,
            deviation: abs(signed),
            signedDeviation: signed
        )
        attempts.append(attempt)
        advanceTarget()
        return attempt
    }

    private func advanceTarget() {
        switch order {
        case .sequence:
            currentTarget = speeds[puttsTaken % speeds.count]
        case .random:
            currentTarget = adaptiveEngine.weightedRandomSpeeds(from: speeds, count: 1).first ?? currentTarget
        }
    }
}
