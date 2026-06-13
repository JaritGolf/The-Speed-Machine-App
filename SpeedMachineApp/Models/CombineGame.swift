//
//  CombineGame.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import Foundation
import Combine

class CombineGame: ObservableObject {
    @Published var currentShot: Int = 0
    @Published var totalScore: Int = 0
    @Published var shots: [CombineShot] = []
    @Published var isComplete: Bool = false

    let targets: [Int] = [
        6, 10, 14, 18,     // Shot 1-4: One from each zone (low to high)
        3, 7, 11, 15, 19,  // Shot 5-9: Full spectrum
        6, 10, 14, 18,     // Shot 10-13: Repeat zones
        8, 12, 16, 20,     // Shot 14-17: Different speeds
        10                  // Shot 18: Medium finish
    ]

    func recordShot(actualSpeed: Float) {
        guard currentShot < TrainingConstants.combineShots else { return }

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

        if currentShot >= TrainingConstants.combineShots {
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

    // Maximum possible score calculation
    static var maxPossibleScore: Int {
        let game = CombineGame()
        var total = 0
        for target in game.targets {
            let zone = SpeedZone.getZone(for: target)
            total += Int(10.0 * zone.multiplier)
        }
        return total
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
