//
//  CombineViewModel.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import Foundation
import Combine

class CombineViewModel: ObservableObject {
    @Published var game = CombineGame()
    @Published var isGameActive = false
    @Published var highScore: Int = 0

    private let dataService = DataService.shared
    private let statsService = StatsService.shared
    private var gameData: CombineGameData?
    private var gameStartTime: Date?

    init() {
        highScore = dataService.combineHighScore
    }

    func startNewGame() {
        game.reset()
        isGameActive = true
        gameData = dataService.createCombineGame()
        gameStartTime = Date()
    }

    func recordShot(_ speed: Float) {
        guard isGameActive, let gameData = gameData else { return }

        let shotNumber = game.currentShot + 1
        let target = game.currentTarget

        // Round to the displayed 0.1 MPH resolution so scoring and stats see
        // the same number the player does (matches the training path).
        let roundedSpeed = (speed * 10).rounded() / 10

        game.recordShot(actualSpeed: roundedSpeed)

        if let lastShot = game.lastShot {
            dataService.recordCombineShot(
                game: gameData,
                shotNumber: shotNumber,
                targetSpeed: target,
                actualSpeed: roundedSpeed,
                points: lastShot.points,
                accuracy: lastShot.accuracy.rawValue
            )

            // Update lifetime stats (every combine shot feeds the speed profile)
            let tolerance = SpeedZone.getZone(for: target).tolerance
            statsService.recordPutt(
                targetSpeed: target,
                actualSpeed: roundedSpeed,
                tolerance: tolerance
            )
        }

        if game.isComplete {
            completeGame()
        }
    }

    func completeGame() {
        guard let gameData = gameData else { return }

        dataService.completeCombineGame(gameData, finalScore: game.totalScore)

        if game.totalScore > highScore {
            highScore = game.totalScore
        }

        // Track practice time
        if let startTime = gameStartTime {
            statsService.addPracticeTime(seconds: Date().timeIntervalSince(startTime))
        }

        isGameActive = false
    }

    func endGame() {
        // Track practice time even if game ended early
        if let startTime = gameStartTime {
            statsService.addPracticeTime(seconds: Date().timeIntervalSince(startTime))
        }

        isGameActive = false
        game.reset()
        gameData = nil
        gameStartTime = nil
    }

    var maxScore: Int {
        return CombineGame.maxPossibleScore
    }

    var scorePercentage: Double {
        guard maxScore > 0 else { return 0 }
        return Double(game.totalScore) / Double(maxScore)
    }
}
