//
//  CombineModeView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI
import UIKit

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
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 16)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(AppColors.accentGreen.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "target")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.accentGreen)
                    }

                    // Title
                    VStack(spacing: 6) {
                        Text("Combine Mode")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryBlack)

                        Text("18 shots across all zones")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textMuted)
                    }

                    // Stats Card
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("High Score")
                                .font(.caption)
                                .foregroundColor(AppColors.textMuted)
                            Text("\(combineViewModel.highScore)")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.primaryBlack)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Max Possible")
                                .font(.caption)
                                .foregroundColor(AppColors.textMuted)
                            Text("\(combineViewModel.maxScore)")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.textMuted)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.border, lineWidth: 1)
                    )

                    // How it works Card
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.border, lineWidth: 1)
                    )

                    // Start Button
                    Button {
                        if bluetoothService.isConnected {
                            combineViewModel.startNewGame()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.body.weight(.semibold))
                            Text(bluetoothService.isConnected ? "Start Combine" : "Connect Device First")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textMuted)
                        .cornerRadius(12)
                    }
                    .disabled(!bluetoothService.isConnected)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct ActiveCombineView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    @State private var showEndGameAlert = false
    @Environment(\.verticalSizeClass) var verticalSizeClass

    var game: CombineGame { combineViewModel.game }
    var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        VStack(spacing: 0) {
            // Compact header
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "target").font(.subheadline).foregroundColor(AppColors.accentGreen)
                        Text("COMBINE").font(.subheadline).fontWeight(.bold).foregroundColor(AppColors.textMuted).tracking(1)
                    }
                    Spacer()
                    Text("Shot \(game.currentShot + 1)/\(TrainingConstants.combineShots)")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(AppColors.primaryBlack)
                    Spacer()
                    let zone = game.currentZone
                    Text("\(zone.name) \(zone.multiplier, specifier: "%.1f")x")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(AppColors.accentGreen)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(AppColors.accentLight).cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Color.white.ignoresSafeArea(edges: .top))
            .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .bottom)

            if isLandscape {
                // LANDSCAPE: side-by-side, fills viewport
                GeometryReader { geo in
                    HStack(spacing: 12) {
                        // Left: big target
                        VStack(spacing: 0) {
                            Spacer()
                            Text("TARGET")
                                .font(.caption).fontWeight(.bold).foregroundColor(AppColors.textMuted).tracking(1.5)
                            Text("\(game.currentTarget)")
                                .font(.system(size: 200, weight: .black, design: .rounded))
                                .foregroundColor(AppColors.primaryBlack)
                                .minimumScaleFactor(0.3).lineLimit(1)
                            Text("MPH")
                                .font(.title2).fontWeight(.bold).foregroundColor(AppColors.textMuted)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white).cornerRadius(24)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.border, lineWidth: 1))

                        // Right: scores + last shot + end
                        VStack(spacing: 10) {
                            // Score row
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Score").font(.subheadline).foregroundColor(AppColors.textMuted)
                                    Text("\(game.totalScore)")
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(AppColors.primaryBlack)
                                        .minimumScaleFactor(0.4).lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Best").font(.subheadline).foregroundColor(AppColors.textMuted)
                                    Text("\(combineViewModel.highScore)")
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(AppColors.accentGreen)
                                        .minimumScaleFactor(0.4).lineLimit(1)
                                }
                            }
                            .padding(14)
                            .background(Color.white).cornerRadius(18)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.border, lineWidth: 1))

                            // Last shot
                            if let lastShot = game.lastShot {
                                HStack {
                                    Text(lastShot.actualSpeed.toSpeedString())
                                        .font(.system(.title2, design: .rounded).weight(.bold))
                                        .foregroundColor(AppColors.textMuted)
                                    Image(systemName: "arrow.right").font(.subheadline).foregroundColor(AppColors.textMuted)
                                    Text("+\(lastShot.points)")
                                        .font(.system(.title2, design: .rounded).weight(.bold))
                                        .foregroundColor(lastShot.accuracy.color)
                                    Text("(\(lastShot.accuracy.rawValue))")
                                        .font(.subheadline).foregroundColor(AppColors.textMuted)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(lastShot.accuracy.color.opacity(0.08)).cornerRadius(14)
                            }

                            Spacer()

                            // End game + logo
                            HStack(spacing: 12) {
                                Button {
                                    showEndGameAlert = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark.circle").font(.body)
                                        Text("End Game").font(.body).fontWeight(.medium)
                                    }
                                    .foregroundColor(AppColors.error)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Color.white).cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.error.opacity(0.3), lineWidth: 1))
                                }
                                LogoBadge()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, max(8, geo.safeAreaInsets.bottom))
                    .padding(.leading, max(16, geo.safeAreaInsets.leading + 4))
                    .padding(.trailing, max(16, geo.safeAreaInsets.trailing + 4))
                }
                .ignoresSafeArea(edges: .horizontal)
            } else {
                // PORTRAIT: fills viewport
                VStack(spacing: 12) {
                    // Target - fills available space
                    VStack(spacing: 0) {
                        Spacer()
                        Text("TARGET")
                            .font(.headline).fontWeight(.bold).foregroundColor(AppColors.textMuted).tracking(2)
                        Text("\(game.currentTarget)")
                            .font(.system(size: 220, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.primaryBlack)
                            .minimumScaleFactor(0.3).lineLimit(1)
                        Text("MPH")
                            .font(.title).fontWeight(.bold).foregroundColor(AppColors.textMuted)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white).cornerRadius(24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.border, lineWidth: 1))

                    // Scores
                    VStack(spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Score").font(.subheadline).foregroundColor(AppColors.textMuted)
                                Text("\(game.totalScore)")
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.primaryBlack)
                                    .minimumScaleFactor(0.4).lineLimit(1)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("High Score").font(.subheadline).foregroundColor(AppColors.textMuted)
                                Text("\(combineViewModel.highScore)")
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.accentGreen)
                                    .minimumScaleFactor(0.4).lineLimit(1)
                            }
                        }

                        if let lastShot = game.lastShot {
                            HStack {
                                Text(lastShot.actualSpeed.toSpeedString())
                                    .font(.system(.title2, design: .rounded).weight(.bold)).foregroundColor(AppColors.textMuted)
                                Image(systemName: "arrow.right").font(.subheadline).foregroundColor(AppColors.textMuted)
                                Text("+\(lastShot.points)")
                                    .font(.system(.title2, design: .rounded).weight(.bold)).foregroundColor(lastShot.accuracy.color)
                                Text("(\(lastShot.accuracy.rawValue))").font(.subheadline).foregroundColor(AppColors.textMuted)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(lastShot.accuracy.color.opacity(0.08)).cornerRadius(14)
                        }
                    }
                    .padding(18)
                    .background(Color.white).cornerRadius(24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.border, lineWidth: 1))

                    // End game + logo
                    HStack(spacing: 12) {
                        Button {
                            showEndGameAlert = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle").font(.body)
                                Text("End Game").font(.body).fontWeight(.medium)
                            }
                            .foregroundColor(AppColors.error)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.white).cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.error.opacity(0.3), lineWidth: 1))
                        }
                        LogoBadge()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .padding(.top, 6)
            }
        }
        .alert("End Game?", isPresented: $showEndGameAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { combineViewModel.endGame() }
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
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.accentLight)
                    .frame(width: 140, height: 140)

                if isNewHighScore {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 64))
                        .foregroundColor(AppColors.accentGreen)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(AppColors.accentGreen)
                }
            }

            // Title
            VStack(spacing: 8) {
                if isNewHighScore {
                    Text("New High Score!")
                        .font(.largeTitle).fontWeight(.bold).foregroundColor(AppColors.accentGreen)
                } else {
                    Text("Combine Complete!")
                        .font(.largeTitle).fontWeight(.bold).foregroundColor(AppColors.primaryBlack)
                }
                Text(scoreRating)
                    .font(.title3).foregroundColor(AppColors.textMuted)
            }

            // Score Display Card
            VStack(spacing: 14) {
                Text("\(game.totalScore)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.primaryBlack)
                    .minimumScaleFactor(0.4).lineLimit(1)

                Text("out of \(combineViewModel.maxScore) possible points")
                    .font(.body).foregroundColor(AppColors.textMuted)

                ProgressBarView(
                    current: game.totalScore,
                    total: combineViewModel.maxScore,
                    color: AppColors.accentGreen
                )
                .frame(height: 14)
            }
            .padding(24)
            .background(Color.white).cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.border, lineWidth: 1))

            // Stats Breakdown Card
            VStack(spacing: 14) {
                Text("Performance Breakdown")
                    .font(.title3).fontWeight(.bold).foregroundColor(AppColors.primaryBlack)

                let breakdown = getAccuracyBreakdown()
                ForEach(Array(breakdown.keys.sorted(by: { AccuracyTier(rawValue: $0)?.basePoints ?? 0 > AccuracyTier(rawValue: $1)?.basePoints ?? 0 })), id: \.self) { key in
                    if let count = breakdown[key], count > 0 {
                        HStack {
                            Text(key).font(.body).foregroundColor(AppColors.textMuted)
                            Spacer()
                            Text("\(count)")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundColor(AppColors.primaryBlack)
                        }
                    }
                }
            }
            .padding(24)
            .background(Color.white).cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.border, lineWidth: 1))

            Spacer()

            // Buttons
            VStack(spacing: 10) {
                Button {
                    combineViewModel.startNewGame()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise").font(.title3.weight(.semibold))
                        Text("Play Again").font(.title3).fontWeight(.semibold)
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(AppColors.accentGreen).cornerRadius(18)
                }

                Button {
                    combineViewModel.endGame()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark").font(.title3.weight(.semibold))
                        Text("Done").font(.title3).fontWeight(.semibold)
                    }
                    .foregroundColor(AppColors.primaryBlack).frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(Color.white).cornerRadius(18)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.border, lineWidth: 1))
                }
            }
        }
        .padding(20)
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
