//
//  HomeView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var combineViewModel: CombineViewModel
    @EnvironmentObject var dataService: DataService

    @EnvironmentObject var statsService: StatsService

    @State private var showConnectionView = false
    @State private var showTrainingView = false
    @State private var showCombineView = false
    @State private var showProgressView = false
    @State private var showStatsView = false
    @State private var showSettingsView = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Custom Title Header
                        HStack {
                            VStack(alignment: .leading, spacing: -4) {
                                Text("The")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(AppColors.accentGreen)
                                Text("Speed Machine")
                                    .font(.system(size: 45, weight: .bold))
                                    .foregroundColor(AppColors.accentGreen)
                            }
                            Spacer()
                        }
                        .opacity(0.5)

                        // Device Status Card
                        DeviceStatusCard(showConnectionView: $showConnectionView)

                        // Training Program Card
                        TrainingProgramCard(showTrainingView: $showTrainingView)

                        // Combine Mode Card
                        CombineModeCard(showCombineView: $showCombineView)

                        // Stats Card
                        StatsHomeCard(showStatsView: $showStatsView)

                        // Progress Stats Card
                        ProgressStatsCard(showProgressView: $showProgressView)

                        // Jarit Golf Logo
                        VStack(spacing: 0) {
                            Spacer(minLength: 20)
                            HStack {
                                Spacer()
                                Image("JaritGolfLogo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 100)
                                    .opacity(0.2)
                            }
                            Spacer(minLength: 8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    // On iPad, centre the card stack so it doesn't stretch wall-to-wall
                    .adaptiveContentFrame(maxWidth: 680)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showSettingsView = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(AppColors.primaryBlack)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showConnectionView) {
                ConnectionView()
            }
            .fullScreenCover(isPresented: $showTrainingView) {
                DaySelectionView()
            }
            .fullScreenCover(isPresented: $showCombineView) {
                CombineModeView()
            }
            .fullScreenCover(isPresented: $showProgressView) {
                ProgressDashboardView()
            }
            .fullScreenCover(isPresented: $showStatsView) {
                StatsDashboardView()
            }
            .fullScreenCover(isPresented: $showSettingsView) {
                SettingsView()
            }
        }
        .ignoresSafeArea()
        .navigationViewStyle(.stack)
        .background(AppColors.backgroundAlt.ignoresSafeArea())
    }
}

struct DeviceStatusCard: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    @Binding var showConnectionView: Bool

    var statusColor: Color {
        bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textMuted
    }

    var body: some View {
        Button {
            showConnectionView = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(bluetoothService.isConnected ? AppColors.bleBlue.opacity(0.15) : AppColors.textMuted.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title3)
                        .foregroundColor(bluetoothService.isConnected ? AppColors.bleBlue : AppColors.textMuted)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Device")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryBlack)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textMuted)
                            .frame(width: 8, height: 8)

                        Text(bluetoothService.connectionState.rawValue)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textMuted)
                    }
                }

                Spacer()

                if bluetoothService.isConnected {
                    HStack(spacing: 4) {
                        Image(systemName: "battery.100")
                            .foregroundColor(AppColors.accentGreen)
                        Text("\(bluetoothService.batteryLevel)%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textMuted)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColors.textMuted)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }
}

struct TrainingProgramCard: View {
    @EnvironmentObject var dataService: DataService
    @Binding var showTrainingView: Bool

    var body: some View {
        Button {
            showTrainingView = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accentGreen.opacity(0.15))
                            .frame(width: 50, height: 50)

                        Image(systemName: "figure.golf")
                            .font(.title3)
                            .foregroundColor(AppColors.accentGreen)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Training Program")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryBlack)

                        Text("Day \(dataService.userProgress.currentDay) of \(TrainingConstants.totalDays)")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColors.textMuted)
                }

                ProgressBarView(
                    current: Int(dataService.userProgress.currentDay),
                    total: TrainingConstants.totalDays,
                    color: AppColors.accentGreen
                )

                HStack {
                    Text("Continue Training")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColors.accentGreen)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }
}

struct CombineModeCard: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @Binding var showCombineView: Bool

    var body: some View {
        Button {
            showCombineView = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.accentGreen.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: "target")
                        .font(.title3)
                        .foregroundColor(AppColors.accentGreen)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Combine Mode")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryBlack)

                    HStack(spacing: 8) {
                        Label("18 shots", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)

                        Text("High Score: \(combineViewModel.highScore)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.accentGreen)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textMuted)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }
}

struct ProgressStatsCard: View {
    @EnvironmentObject var dataService: DataService
    @Binding var showProgressView: Bool

    var completedDays: Int {
        dataService.getAllCompletedDays().count
    }

    var totalPutts: Int {
        Int(dataService.userProgress.totalPutts)
    }

    var body: some View {
        Button {
            showProgressView = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accentGreen.opacity(0.15))
                            .frame(width: 50, height: 50)

                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.accentGreen)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Progress")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryBlack)

                        Text("View your training stats")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColors.textMuted)
                }

                HStack(spacing: 0) {
                    StatPill(value: "\(completedDays)", label: "Days", icon: "checkmark.circle")
                    StatPill(value: "\(totalPutts)", label: "Putts", icon: "figure.golf")
                    StatPill(value: "\(Int(dataService.userProgress.currentPhase))", label: "Phase", icon: "star.fill")
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }
}

struct StatPill: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(AppColors.accentGreen)

            VStack(spacing: 2) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(AppColors.primaryBlack)

                Text(label)
                    .font(.caption2)
                    .foregroundColor(AppColors.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppColors.backgroundAlt)
        .cornerRadius(8)
    }
}

struct StatsHomeCard: View {
    @EnvironmentObject var statsService: StatsService
    @Binding var showStatsView: Bool

    var body: some View {
        Button {
            showStatsView = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.bleBlue.opacity(0.15))
                            .frame(width: 50, height: 50)

                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3)
                            .foregroundColor(AppColors.bleBlue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Stats")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryBlack)

                        Text("Speed profiles, trends & deep dives")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColors.textMuted)
                }

                // Mini speed ladder preview (top 3 weakest)
                if !statsService.weakestSpeeds.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)

                        Text("Focus: \(statsService.weakestSpeeds.map { "\($0.targetSpeed) MPH" }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(6)
                } else if statsService.totalLifetimePutts > 0 {
                    HStack(spacing: 0) {
                        StatPill(
                            value: String(format: "%.0f%%", statsService.overallAccuracy),
                            label: "Accuracy",
                            icon: "target"
                        )
                        StatPill(
                            value: "\(statsService.totalLifetimePutts)",
                            label: "Putts",
                            icon: "figure.golf"
                        )
                        StatPill(
                            value: "\(statsService.currentPracticeStreak)",
                            label: "Streak",
                            icon: "flame.fill"
                        )
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }
}

struct ProgressBarView: View {
    let current: Int
    let total: Int
    let color: Color

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(AppColors.backgroundAlt)
                    .frame(height: 8)
                    .cornerRadius(4)

                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * progress, height: 8)
                    .cornerRadius(4)
            }
        }
        .frame(height: 8)
    }
}
