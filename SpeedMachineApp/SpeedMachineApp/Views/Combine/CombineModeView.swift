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
            Color.white.ignoresSafeArea()

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
        .onChange(of: bluetoothService.currentSpeed) { _, newSpeed in
            if combineViewModel.isGameActive && !combineViewModel.game.isComplete {
                if newSpeed > 0 && newSpeed != lastRecordedSpeed {
                    combineViewModel.recordShot(newSpeed)
                    lastRecordedSpeed = newSpeed
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
            }
        }
    }
}

// MARK: - Pre-game Screen

struct CombineStartView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    @Environment(\.dismiss) var dismiss

    private let howItWorks: [(String, String)] = [
        ("18 putts across all speed zones", "Zones 1–5 · targets vary each shot"),
        ("Points based on precision", "Perfect 10 · Excellent 8 · Good 6 · In Zone 4 · Close 2"),
        ("Higher zones multiply your score", "Touch 1.0× → Maximum 2.0×"),
        ("Every shot feeds your Stats", "Speed profiles update in real time")
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    Spacer()
                    Text("COMBINE")
                        .font(.custom("Inter-Bold", size: 13))
                        .kerning(2.5)
                        .foregroundColor(.black)
                    Spacer()
                    Color.clear.frame(width: 28, height: 28)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 12)

                Divider().overlay(AppColors.border)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Score row
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("HIGH SCORE")
                                    .font(.custom("Inter-Bold", size: 10))
                                    .kerning(2.0)
                                    .foregroundColor(AppColors.textSubdued)
                                Text("\(combineViewModel.highScore)")
                                    .font(.custom("Inter-Black", size: 48))
                                    .foregroundColor(AppColors.accentGreen)
                                    .tracking(-1)
                                Text("points")
                                    .font(.custom("Inter-Regular", size: 12))
                                    .foregroundColor(AppColors.textSubdued)
                            }

                            Spacer()

                            Rectangle()
                                .fill(AppColors.border)
                                .frame(width: 1, height: 70)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("MAX POSSIBLE")
                                    .font(.custom("Inter-Bold", size: 10))
                                    .kerning(2.0)
                                    .foregroundColor(AppColors.textSubdued)
                                Text("\(combineViewModel.maxScore)")
                                    .font(.custom("Inter-Black", size: 48))
                                    .foregroundColor(Color(hex: "d4d4d4"))
                                    .tracking(-1)
                                Text("points")
                                    .font(.custom("Inter-Regular", size: 12))
                                    .foregroundColor(AppColors.textSubdued)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 24)

                        Divider().overlay(AppColors.border)

                        // HOW IT WORKS
                        VStack(alignment: .leading, spacing: 0) {
                            Text("HOW IT WORKS")
                                .font(.custom("Inter-Bold", size: 10))
                                .kerning(2.5)
                                .foregroundColor(AppColors.textSubdued)
                                .padding(.horizontal, 22)
                                .padding(.top, 20)
                                .padding(.bottom, 14)

                            ForEach(howItWorks, id: \.0) { title, subtitle in
                                VStack(spacing: 0) {
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(AppColors.accentGreen)
                                            .frame(width: 20, height: 20)
                                            .padding(.top, 1)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(title)
                                                .font(.custom("Inter-SemiBold", size: 15))
                                                .foregroundColor(.black)
                                            Text(subtitle)
                                                .font(.custom("Inter-Regular", size: 12))
                                                .foregroundColor(AppColors.textMuted)
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 14)

                                    Divider().overlay(AppColors.border)
                                }
                            }
                        }

                        // CTA
                        Button {
                            if bluetoothService.isConnected {
                                combineViewModel.startNewGame()
                            }
                        } label: {
                            Text(bluetoothService.isConnected ? "Start Combine" : "Connect Device First")
                                .font(.custom("Inter-Bold", size: 17))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textSubdued)
                                .clipShape(Capsule())
                        }
                        .disabled(!bluetoothService.isConnected)
                        .padding(.horizontal, 22)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }
}

// MARK: - Live Game Screen

struct ActiveCombineView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @EnvironmentObject var bluetoothService: BluetoothService

    @State private var showEndGameAlert = false

    var game: CombineGame { combineViewModel.game }

    private var remainingTargets: [Int] {
        Array(game.targets.suffix(from: min(game.currentShot, game.targets.count)))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textSubdued)
                    .frame(width: 8, height: 8)
                Text("COMBINE")
                    .font(.custom("Inter-Bold", size: 13))
                    .kerning(2.5)
                    .foregroundColor(.black)
                Spacer()
                Text("SCORE")
                    .font(.custom("Inter-Bold", size: 11))
                    .kerning(1.5)
                    .foregroundColor(AppColors.textSubdued)
                Text("\(game.totalScore)")
                    .font(.custom("Inter-Black", size: 22))
                    .foregroundColor(.black)
                    .tracking(-0.5)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)

            Divider().overlay(AppColors.border)

            // REMAINING chips
            VStack(alignment: .leading, spacing: 10) {
                Text("REMAINING")
                    .font(.custom("Inter-Bold", size: 10))
                    .kerning(2.0)
                    .foregroundColor(AppColors.textSubdued)
                    .padding(.horizontal, 22)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(remainingTargets.enumerated()), id: \.offset) { idx, target in
                            let isCurrent = idx == 0
                            Text("\(target)")
                                .font(.custom("Inter-Bold", size: 13))
                                .foregroundColor(isCurrent ? .white : AppColors.textMuted)
                                .frame(width: 42, height: 42)
                                .background(isCurrent ? AppColors.accentGreen : AppColors.surfaceAlt)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 22)
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().overlay(AppColors.border)

            Spacer()

            // Hero target number
            VStack(spacing: 0) {
                Text("\(game.currentTarget)")
                    .font(.system(size: fs(200), weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .tracking(-4)

                Text("MPH  ·  TARGET")
                    .font(.custom("Inter-Bold", size: 13))
                    .kerning(2.0)
                    .foregroundColor(AppColors.textSubdued)
            }

            Spacer()

            Divider().overlay(AppColors.border)

            // Last shot
            HStack(spacing: 12) {
                if let lastShot = game.lastShot {
                    Text(lastShot.actualSpeed.toSpeedString())
                        .font(.custom("Inter-Black", size: 22))
                        .foregroundColor(.black)
                    Text("+\(lastShot.points)")
                        .font(.custom("Inter-Bold", size: 17))
                        .foregroundColor(AppColors.accentGreen)
                    Text(lastShot.accuracy.rawValue.uppercased())
                        .font(.custom("Inter-Bold", size: 13))
                        .kerning(1.0)
                        .foregroundColor(AppColors.textSubdued)
                } else {
                    Text("LAST SHOT")
                        .font(.custom("Inter-Bold", size: 13))
                        .kerning(2.0)
                        .foregroundColor(AppColors.textSubdued)
                }
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)

            Divider().overlay(AppColors.border)

            // END GAME button
            Button { showEndGameAlert = true } label: {
                Text("END GAME")
                    .font(.custom("Inter-Bold", size: 15))
                    .foregroundColor(AppColors.error)
                    .kerning(1.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.error, lineWidth: 1.5)
                    )
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
        .background(Color.white.ignoresSafeArea())
        .alert("End Game?", isPresented: $showEndGameAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { combineViewModel.endGame() }
        } message: {
            Text("End this game? Your progress will not be saved.")
        }
    }
}

// MARK: - Complete Screen (full black)

struct CombineCompleteView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @Environment(\.dismiss) var dismiss

    var game: CombineGame { combineViewModel.game }

    var isNewHighScore: Bool { game.totalScore >= combineViewModel.highScore }

    var scoreRating: String {
        let pct = Double(game.totalScore) / Double(combineViewModel.maxScore)
        if pct >= 0.75 { return "Outstanding!" }
        if pct >= 0.60 { return "Excellent!" }
        if pct >= 0.45 { return "Great Job!" }
        if pct >= 0.30 { return "Good Effort!" }
        return "Keep Practicing!"
    }

    private var orderedTiers: [AccuracyTier] {
        [.perfect, .excellent, .good, .inZone, .close, .miss]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 40)

                    // Trophy / icon
                    Image(systemName: "trophy.fill")
                        .font(.system(size: fs(56)))
                        .foregroundColor(isNewHighScore ? AppColors.accentGreen : .white.opacity(0.60))
                        .padding(.bottom, 16)

                    // Title
                    if isNewHighScore {
                        Text("NEW HIGH SCORE")
                            .font(.custom("Inter-Black", size: fs(32)))
                            .foregroundColor(AppColors.accentGreen)
                            .tracking(1)
                    } else {
                        Text("COMBINE COMPLETE")
                            .font(.custom("Inter-Black", size: fs(32)))
                            .foregroundColor(.white)
                            .tracking(1)
                    }

                    Text(scoreRating)
                        .font(.custom("Inter-Regular", size: fs(16)))
                        .foregroundColor(.white.opacity(0.60))
                        .padding(.top, 6)

                    Spacer(minLength: 24)

                    // Score hero
                    Text("\(game.totalScore)")
                        .font(.custom("Inter-Black", size: fs(96)))
                        .foregroundColor(.white)
                        .tracking(-2)

                    Text("of \(combineViewModel.maxScore) possible points")
                        .font(.custom("Inter-Regular", size: fs(14)))
                        .foregroundColor(.white.opacity(0.50))
                        .padding(.top, 4)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppColors.accentGreen)
                                .frame(width: max(0, geo.size.width * CGFloat(game.totalScore) / CGFloat(max(1, combineViewModel.maxScore))), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .padding(.bottom, 32)

                    // Accuracy breakdown
                    VStack(spacing: 0) {
                        let breakdown = getBreakdown()
                        ForEach(orderedTiers, id: \.rawValue) { tier in
                            let count = breakdown[tier.rawValue] ?? 0
                            HStack {
                                Text(tier.rawValue.uppercased())
                                    .font(.custom("Inter-Bold", size: 13))
                                    .kerning(1.0)
                                    .foregroundColor(tier == .miss ? AppColors.error : .white.opacity(0.70))
                                Spacer()
                                Text("\(count)")
                                    .font(.custom("Inter-Black", size: 20))
                                    .foregroundColor(tier == .miss ? AppColors.error : .white)
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)

                            if tier != .miss {
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 1)
                                    .padding(.horizontal, 32)
                            }
                        }
                    }
                    .padding(.bottom, 32)

                    // Buttons
                    VStack(spacing: 10) {
                        Button {
                            combineViewModel.startNewGame()
                        } label: {
                            Text("Play Again")
                                .font(.custom("Inter-Bold", size: 17))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(AppColors.accentGreen)
                                .clipShape(Capsule())
                        }

                        Button {
                            combineViewModel.endGame()
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.custom("Inter-Bold", size: 17))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color.clear)
                                .overlay(Capsule().stroke(Color.white.opacity(0.30), lineWidth: 1.5))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    func getBreakdown() -> [String: Int] {
        var b: [String: Int] = [:]
        for shot in game.shots { b[shot.accuracy.rawValue, default: 0] += 1 }
        return b
    }
}
