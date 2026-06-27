//
//  CombineGame.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import Foundation
import Combine

/// The selectable Combine game modes. Each mode defines the pool of target speeds it draws
/// from. Which speeds are actually playable is gated by the golfer's Training progress
/// (see MasteryService.eligibleSpeeds / isModeUnlocked).
///
/// Note: lives here rather than its own file because the app target compiles an explicit
/// source list — a new standalone file would need manual pbxproj wiring to be picked up.
enum CombineMode: String, CaseIterable, Identifiable {
    case main   // 3–20, grows with unlocked speeds
    case low    // 3–10
    case high   // 11–20
    case even   // even speeds only: 4, 6, 8, 10, 12, 14, 16, 18, 20

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main: return "Main"
        case .low:  return "Low Speeds"
        case .high: return "High Speeds"
        case .even: return "Even Numbers"
        }
    }

    /// Short range descriptor shown under the title.
    var rangeLabel: String {
        switch self {
        case .main: return "3–20 MPH"
        case .low:  return "3–10 MPH"
        case .high: return "11–20 MPH"
        case .even: return "Even · 4–20 MPH"
        }
    }

    /// Per-mode high-score storage key (iCloud KV + UserDefaults).
    var highScoreKey: String { "combineHighScore_\(rawValue)" }

    /// Full (unfiltered) speed pool for this mode, before unlock gating.
    func allSpeeds() -> [Int] {
        switch self {
        case .main: return Array(3...20)
        case .low:  return Array(3...10)
        case .high: return Array(11...20)
        case .even: return stride(from: 4, through: 20, by: 2).map { $0 }  // 9 speeds
        }
    }
}

class CombineGame: ObservableObject {
    @Published var currentShot: Int = 0
    @Published var totalScore: Int = 0
    @Published var shots: [CombineShot] = []
    @Published var isComplete: Bool = false

    /// The pool of target speeds this game draws from — set by the selected Combine mode,
    /// already filtered to the golfer's unlocked speeds (see MasteryService.eligibleSpeeds).
    let speeds: [Int]

    @Published var targets: [Int] = []

    init(speeds: [Int]) {
        self.speeds = speeds
        targets = Self.generateTargets(from: speeds)
    }

    /// One shot per speed per session: every eligible speed in the mode's pool appears exactly
    /// once, in random play order. Reshuffled each game so the order can't be memorized.
    /// (The live view displays these sorted low→high; the shuffle only sets which speed is the
    /// current target next.)
    private static func generateTargets(from speeds: [Int]) -> [Int] {
        guard !speeds.isEmpty else { return [] }
        return speeds.shuffled()
    }

    func recordShot(actualSpeed: Float) {
        guard currentShot < targets.count else { return }

        let target = targets[currentShot]
        let (points, tier) = calculateScore(target: target, actual: actualSpeed)

        let shot = CombineShot(
            shotNumber: currentShot + 1,
            targetSpeed: target,
            actualSpeed: actualSpeed,
            points: points,
            accuracy: tier
        )

        shots.append(shot)
        totalScore += points
        currentShot += 1

        if currentShot >= targets.count {
            isComplete = true
        }
    }

    func calculateScore(target: Int, actual: Float) -> (points: Int, tier: AccuracyTier) {
        let zone = SpeedZone.getZone(for: target)
        let tolerance = zone.tolerance

        // Compare in integer hundredths of a MPH: tier cutoffs sit on quarter
        // tolerances (e.g. 0.15), and Float math misclassifies exact-boundary
        // shots (10.6 at 10 ±0.6 scored "close" instead of "in zone").
        let devH = abs(SpeedMath.tenths(actual) * 10 - target * 100)
        let tolH = SpeedMath.tenths(tolerance) * 10

        let tier: AccuracyTier
        let basePoints: Int

        switch devH {
        case 0...(tolH / 4):
            tier = .perfect
            basePoints = 10
        case 0...(tolH / 2):
            tier = .excellent
            basePoints = 8
        case 0...(tolH * 3 / 4):
            tier = .good
            basePoints = 6
        case 0...tolH:
            tier = .inZone
            basePoints = 4
        case 0...(tolH * 3 / 2):
            tier = .close
            basePoints = 2
        default:
            tier = .miss
            basePoints = 0
        }

        let finalPoints = Int(Float(basePoints) * zone.multiplier)
        return (finalPoints, tier)
    }

    func reset() {
        currentShot = 0
        totalScore = 0
        shots.removeAll()
        isComplete = false
        targets = Self.generateTargets(from: speeds)
    }

    var currentTarget: Int {
        guard currentShot < targets.count else { return targets.last ?? 10 }
        return targets[currentShot]
    }

    var currentZone: SpeedZone {
        return SpeedZone.getZone(for: currentTarget)
    }

    var lastShot: CombineShot? {
        return shots.last
    }

    // Maximum possible score for the current target set. The target speeds (and thus the
    // mix of zone multipliers) vary by mode and unlock state, so this is computed from the
    // generated targets rather than a fixed pattern.
    var maxPossibleScore: Int {
        targets.reduce(0) { total, target in
            total + Int(10.0 * SpeedZone.getZone(for: target).multiplier)
        }
    }
}

struct CombineShot: Identifiable {
    let id = UUID()
    let shotNumber: Int
    let targetSpeed: Int
    let actualSpeed: Float
    let points: Int
    let accuracy: AccuracyTier

    var difference: Float {
        return abs(actualSpeed - Float(targetSpeed))
    }
}
