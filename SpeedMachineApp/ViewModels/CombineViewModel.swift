//
//  CombineViewModel.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import Foundation
import Combine

class CombineViewModel: ObservableObject {
    @Published var game: CombineGame
    @Published var isGameActive = false
    @Published var selectedMode: CombineMode = .main
    /// High score per mode, keyed by `CombineMode.highScoreKey`.
    @Published var highScores: [String: Int] = [:]
    /// Gates the router's switch to CombineCompleteView. Stays false for a beat
    /// after the final shot so the last putt's result holds on ActiveCombineView
    /// (same 3 s the board holds every other shot's result chip) before the
    /// complete screen takes over.
    @Published var readyToShowComplete = false

    private let dataService = DataService.shared
    private let statsService = StatsService.shared
    private let mastery = MasteryService.shared
    private var gameData: CombineGameData?
    private var gameStartTime: Date?
    private var completeTransitionWorkItem: DispatchWorkItem?

    init() {
        game = CombineGame(speeds: MasteryService.shared.eligibleSpeeds(for: .main))
        loadHighScores()
    }

    private func loadHighScores() {
        var scores: [String: Int] = [:]
        for mode in CombineMode.allCases {
            scores[mode.highScoreKey] = dataService.combineHighScore(forKey: mode.highScoreKey)
        }
        highScores = scores
    }

    /// High score for the currently selected mode.
    var highScore: Int { highScores[selectedMode.highScoreKey] ?? 0 }

    /// High score for a specific mode (used by the picker).
    func highScore(for mode: CombineMode) -> Int { highScores[mode.highScoreKey] ?? 0 }

    func startNewGame(mode: CombineMode) {
        completeTransitionWorkItem?.cancel()
        readyToShowComplete = false
        selectedMode = mode
        game = CombineGame(speeds: mastery.eligibleSpeeds(for: mode))
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

        dataService.completeCombineGame(gameData, finalScore: game.totalScore, modeKey: selectedMode.highScoreKey)
        loadHighScores()

        // Track practice time
        if let startTime = gameStartTime {
            statsService.addPracticeTime(seconds: Date().timeIntervalSince(startTime))
        }

        // isGameActive stays true here — it means "there is a game session to
        // display" (active or just-completed). CombineModeView's router uses
        // game.isComplete to switch between ActiveCombineView and
        // CombineCompleteView. Only endGame() (Play Again / Done / early
        // abort) sets isGameActive back to false. Previously this line set
        // isGameActive = false here too, which made the router fall straight
        // back to the mode's pre-game CombineStartView on the final putt,
        // skipping CombineCompleteView entirely.

        // Hold on ActiveCombineView for the same 3 s every other shot's result
        // chip gets (see ActiveCombineContent) before the router is allowed to
        // switch to CombineCompleteView, so the last putt's result is visible
        // instead of being replaced instantly by the complete screen.
        let workItem = DispatchWorkItem { [weak self] in
            self?.readyToShowComplete = true
        }
        completeTransitionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }

    func endGame() {
        completeTransitionWorkItem?.cancel()
        readyToShowComplete = false

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
        return game.maxPossibleScore
    }

    var scorePercentage: Double {
        guard maxScore > 0 else { return 0 }
        return Double(game.totalScore) / Double(maxScore)
    }
}
