//
//  CombineModeView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

struct CombineModeView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    @Environment(\.dismiss) var dismiss

    @State private var lastRecordedSpeed: Float = 0.0

    var body: some View {
        ZStack {
            AppColors.backgroundAlt.ignoresSafeArea()

            if combineViewModel.isGameActive {
                if combineViewModel.game.isComplete {
                    CombineCompleteView()
                } else {
                    ActiveCombineView()
                }
            } else {
                CombineStartView()
            }
        }
        .onChange(of: bluetoothService.currentSpeed) { newSpeed in
            if combineViewModel.isGameActive && !combineViewModel.game.isComplete {
                if newSpeed > 0 && newSpeed != lastRecordedSpeed {
                    combineViewModel.recordShot(newSpeed)
                    lastRecordedSpeed = newSpeed

                    // Haptic feedback
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
            }
        }
    }
}

struct CombineStartView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                // Icon
                Image(systemName: "target")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.accentGreen)

                // Title
                VStack(spacing: 8) {
                    Text("Combine Mode")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryBlack)

                    Text("18 shots across all zones")
                        .font(.headline)
                        .foregroundColor(AppColors.textMuted)
                }

                // Stats
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("High Score")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textMuted)
                            Text("\(combineViewModel.highScore)")
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundColor(AppColors.primaryBlack)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Max Possible")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textMuted)
                            Text("\(combineViewModel.maxScore)")
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundColor(AppColors.textMuted)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)

                // How it works
                VStack(alignment: .leading, spacing: 12) {
                    Text("How it Works")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryBlack)

                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(text: "18 putts with varying targets")
                        InfoRow(text: "Points based on accuracy")
                        InfoRow(text: "Higher zones worth more points")
                        InfoRow(text: "Perfect putt = 10 base points")
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)

                Spacer()

                // Start Button
                Button {
                    if bluetoothService.isConnected {
                        combineViewModel.startNewGame()
                    }
                } label: {
                    Text(bluetoothService.isConnected ? "Start Combine" : "Connect Device First")
                        .primaryButtonStyle()
                }
                .disabled(!bluetoothService.isConnected)
                .padding(.horizontal)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ActiveCombineView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    @State private var showEndGameAlert = false

    var game: CombineGame {
        combineViewModel.game
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("COMBINE MODE")
                    .font(.headline)
                    .foregroundColor(AppColors.textMuted)

                Text("Shot \(game.currentShot + 1) / \(TrainingConstants.combineShots)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryBlack)
            }
            .padding()
            .background(Color.white)

            Spacer()

            // Target Display
            VStack(spacing: 16) {
                Text("TARGET")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textMuted)

                Text("\(game.currentTarget)")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.primaryBlack)

                Text("MPH")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textMuted)

                // Zone info
                let zone = game.currentZone
                Text("\(zone.name) (\(zone.multiplier, specifier: "%.1f")x)")
                    .font(.headline)
                    .foregroundColor(AppColors.accentGreen)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.accentLight)
                    .cornerRadius(20)
            }

            Spacer()

            // Score Section
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Score")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textMuted)
                        Text("\(game.totalScore)")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundColor(AppColors.primaryBlack)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("High Score")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textMuted)
                        Text("\(combineViewModel.highScore)")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundColor(AppColors.accentGreen)
                    }
                }

                // Last Shot Result
                if let lastShot = game.lastShot {
                    HStack {
                        Text("Last: \(lastShot.actualSpeed.toSpeedString())")
                            .font(.headline)
                            .foregroundColor(AppColors.textMuted)

                        Image(systemName: "arrow.right")
                            .foregroundColor(AppColors.textMuted)

                        Text("+\(lastShot.points) pts")
                            .font(.headline)
                            .foregroundColor(lastShot.accuracy.color)

                        Text("(\(lastShot.accuracy.rawValue))")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textMuted)
                    }
                    .padding()
                    .background(lastShot.accuracy.color.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(Color.white)

            // End Game Button
            Button {
                showEndGameAlert = true
            } label: {
                Text("End Game")
                    .font(.headline)
                    .foregroundColor(AppColors.error)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(Color.white)
        }
        .alert("End Game?", isPresented: $showEndGameAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) {
                combineViewModel.endGame()
            }
        } message: {
            Text("Are you sure you want to end this game? Your progress will not be saved.")
        }
    }
}

struct CombineCompleteView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @Environment(\.dismiss) var dismiss

    var game: CombineGame {
        combineViewModel.game
    }

    var isNewHighScore: Bool {
        game.totalScore >= combineViewModel.highScore
    }

    var scoreRating: String {
        let percentage = Double(game.totalScore) / Double(combineViewModel.maxScore)
        if percentage >= 0.75 { return "Outstanding!" }
        if percentage >= 0.60 { return "Excellent!" }
        if percentage >= 0.45 { return "Great Job!" }
        if percentage >= 0.30 { return "Good Effort!" }
        return "Keep Practicing!"
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.accentLight)
                    .frame(width: 120, height: 120)

                if isNewHighScore {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.accentGreen)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.accentGreen)
                }
            }

            // Title
            VStack(spacing: 8) {
                if isNewHighScore {
                    Text("New High Score!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentGreen)
                } else {
                    Text("Combine Complete!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryBlack)
                }

                Text(scoreRating)
                    .font(.headline)
                    .foregroundColor(AppColors.textMuted)
            }

            // Score Display
            VStack(spacing: 16) {
                Text("\(game.totalScore)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.primaryBlack)

                Text("out of \(combineViewModel.maxScore) possible points")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textMuted)

                ProgressBarView(
                    current: game.totalScore,
                    total: combineViewModel.maxScore,
                    color: AppColors.accentGreen
                )
                .frame(height: 12)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)

            // Stats Breakdown
            VStack(spacing: 12) {
                Text("Performance Breakdown")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryBlack)

                let breakdown = getAccuracyBreakdown()
                ForEach(Array(breakdown.keys.sorted(by: { AccuracyTier(rawValue: $0)?.basePoints ?? 0 > AccuracyTier(rawValue: $1)?.basePoints ?? 0 })), id: \.self) { key in
                    if let count = breakdown[key], count > 0 {
                        HStack {
                            Text(key)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textMuted)

                            Spacer()

                            Text("\(count)")
                                .font(.headline)
                                .foregroundColor(AppColors.primaryBlack)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button {
                    combineViewModel.startNewGame()
                } label: {
                    Text("Play Again")
                        .primaryButtonStyle()
                }

                Button {
                    combineViewModel.endGame()
                    dismiss()
                } label: {
                    Text("Done")
                        .secondaryButtonStyle()
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    func getAccuracyBreakdown() -> [String: Int] {
        var breakdown: [String: Int] = [:]
        for shot in game.shots {
            let key = shot.accuracy.rawValue
            breakdown[key, default: 0] += 1
        }
        return breakdown
    }
}

struct InfoRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(AppColors.accentGreen)

            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.textMuted)

            Spacer()
        }
    }
}
