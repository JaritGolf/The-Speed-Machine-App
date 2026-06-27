//
//  RecallRound.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//
//  "Call the Speed" cold-recall round. The screen prompts a target speed, hides the live
//  reading during the stroke, the golfer putts from feel, then (optionally) the result is
//  revealed. Trains recall-on-demand — the ability to summon a named speed without the
//  on-screen number to chase. Mirrors the shape of CombineGame.
//

import Foundation
import Combine

/// When the golfer learns how a putt went.
enum RecallFeedbackMode: String {
    case coached   // reveal actual speed + zone after each putt
    case blind     // silent per putt; full scorecard only at the end
}

struct RecallAttempt: Identifiable {
    let id = UUID()
    let promptNumber: Int
    let targetSpeed: Int
    let actualSpeed: Float
    let isInZone: Bool
    let deviation: Float        // absolute MPH from target
    let signedDeviation: Float  // actual − target (> 0 = too firm / fast)

    var tooFirm: Bool { signedDeviation > 0 }
}

class RecallRound: ObservableObject {
    @Published var currentPrompt: Int = 0
    @Published var attempts: [RecallAttempt] = []
    @Published var isComplete: Bool = false

    let targets: [Int]
    let feedbackMode: RecallFeedbackMode
    let isMaintenance: Bool

    init(targets: [Int], feedbackMode: RecallFeedbackMode, isMaintenance: Bool = false) {
        self.targets = targets
        self.feedbackMode = feedbackMode
        self.isMaintenance = isMaintenance
    }

    var roundLength: Int { targets.count }

    var currentTarget: Int {
        guard currentPrompt < targets.count else { return targets.last ?? 8 }
        return targets[currentPrompt]
    }

    var promptsRemaining: Int { max(0, targets.count - currentPrompt) }

    var lastAttempt: RecallAttempt? { attempts.last }

    var inZoneCount: Int { attempts.filter { $0.isInZone }.count }

    var averageDeviation: Float {
        guard !attempts.isEmpty else { return 0 }
        return attempts.reduce(0) { $0 + $1.deviation } / Float(attempts.count)
    }

    /// In-zone rate as a whole-number percent. Comparable across round lengths, so it's the
    /// basis for the persisted best score.
    var accuracyPercent: Int {
        guard !attempts.isEmpty else { return 0 }
        return Int((Double(inZoneCount) / Double(attempts.count) * 100).rounded())
    }

    /// Record a putt against the current prompt and advance. Returns the scored attempt.
    @discardableResult
    func recordAttempt(actualSpeed: Float) -> RecallAttempt? {
        guard currentPrompt < targets.count else { return nil }

        let target = targets[currentPrompt]
        let tolerance = SpeedZone.getZone(for: target).tolerance
        // Round to 1 decimal to match the live display precision (same as TrainingViewModel).
        let rounded = (actualSpeed * 10).rounded() / 10
        let signed = rounded - Float(target)
        let deviation = abs(signed)
        // Classify via SpeedMath (integer tenths) — a raw Float compare misclassifies
        // boundary putts like 10.6 at 10 ±0.6. See SpeedMath in Constants.swift.
        let isInZone = SpeedMath.isInZone(actual: actualSpeed, target: target, tolerance: tolerance)

        let attempt = RecallAttempt(
            promptNumber: currentPrompt + 1,
            targetSpeed: target,
            actualSpeed: rounded,
            isInZone: isInZone,
            deviation: deviation,
            signedDeviation: signed
        )
        attempts.append(attempt)
        currentPrompt += 1

        if currentPrompt >= targets.count {
            isComplete = true
        }
        return attempt
    }
}
