//
//  CombineGame.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import Foundation

class CombineGame: ObservableObject {
    @Published var currentShot: Int = 0
    @Published var totalScore: Int = 0
    @Published var shots: [CombineShot] = []
    @Published var isComplete: Bool = false

    let targets: [Int] = [
        5,  8, 11, 14,     // Shot 1-4: One anchor speed from each zone (low to high)
        3,  6,  9, 12, 15, // Shot 5-9: Full spectrum endpoints
        5,  8, 11, 14,     // Shot 10-13: Zone anchors again (contextual interference)
        4,  7, 10, 13,     // Shot 14-17: Off-anchor speeds
        8                  // Shot 18: Moderate finish
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
        let difference = abs(actual - Float(target))

        let tier: AccuracyTier
        let basePoints: Int

        switch difference {
        case 0...(tolerance * 0.25):
            tier = .perfect
            basePoints = 10
        case 0...(tolerance * 0.50):
            tier = .excellent
            basePoints = 8
        case 0...(tolerance * 0.75):
            tier = .good
            basePoints = 6
        case 0...tolerance:
            tier = .inZone
            basePoints = 4
        case 0...(tolerance * 1.5):
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
