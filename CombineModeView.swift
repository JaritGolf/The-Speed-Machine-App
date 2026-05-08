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
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()
                
                if combineViewModel.isGameActive {
                    CombineGameActiveView()
                } else {
                    CombineGameIntroView()
                }
            }
            .navigationTitle("Combine Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CombineGameIntroView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "target")
                    .font(.system(size: 72))
                    .foregroundColor(AppColors.accentGreen)
                
                Text("Combine Challenge")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryBlack)
                
                Text("18 shots across all speed zones")
                    .font(.headline)
                    .foregroundColor(AppColors.textMuted)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                StatRow(title: "High Score", value: "\(combineViewModel.highScore)")
                StatRow(title: "Max Possible", value: "\(combineViewModel.maxScore)")
                StatRow(title: "Total Shots", value: "18")
            }
            .padding()
            .cardStyle()
            .padding(.horizontal)
            
            Spacer()
            
            Button {
                combineViewModel.startNewGame()
            } label: {
                Text("Start Combine")
                    .primaryButtonStyle()
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
}

struct CombineGameActiveView: View {
    @EnvironmentObject var combineViewModel: CombineViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    
    var body: some View {
        VStack(spacing: 24) {
            // Progress
            VStack(spacing: 8) {
                Text("Shot \(combineViewModel.game.currentShot + 1) of \(TrainingConstants.combineShots)")
                    .font(.headline)
                    .foregroundColor(AppColors.textMuted)
                
                ProgressBarView(
                    current: combineViewModel.game.currentShot,
                    total: TrainingConstants.combineShots,
                    color: AppColors.accentGreen
                )
                .frame(height: 8)
                .padding(.horizontal)
            }
            .padding(.top)
            
            // Score
            VStack(spacing: 4) {
                Text("Score")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textMuted)
                
                Text("\(combineViewModel.game.totalScore)")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(AppColors.primaryBlack)
            }
            
            // Target
            VStack(spacing: 16) {
                Text("Target Speed")
                    .font(.headline)
                    .foregroundColor(AppColors.textMuted)
                
                Text("\(combineViewModel.game.currentTarget)")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(AppColors.accentGreen)
                
                Text(combineViewModel.game.currentZone.name)
                    .font(.title3)
                    .foregroundColor(AppColors.textMuted)
            }
            .padding()
            .cardStyle()
            .padding(.horizontal)
            
            // Last shot result
            if let lastShot = combineViewModel.game.lastShot {
                VStack(spacing: 8) {
                    Text(lastShot.accuracy.rawValue)
                        .font(.headline)
                        .foregroundColor(lastShot.accuracy.color)
                    
                    Text("+\(lastShot.points) points")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textMuted)
                }
                .padding()
                .background(lastShot.accuracy.color.opacity(0.1))
                .cornerRadius(DesignConstants.cornerRadiusCard)
                .padding(.horizontal)
            }
            
            // Current speed
            VStack(spacing: 8) {
                Text("Current Speed")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textMuted)
                
                Text(String(format: "%.1f", bluetoothService.currentSpeed))
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(AppColors.primaryBlack)
            }
            
            Spacer()
            
            // Record button
            Button {
                combineViewModel.recordShot(bluetoothService.currentSpeed)
            } label: {
                Text("Record Shot")
                    .primaryButtonStyle()
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            .disabled(!bluetoothService.isConnected)
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.textMuted)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundColor(AppColors.primaryBlack)
        }
    }
}

#Preview {
    CombineModeView()
        .environmentObject(CombineViewModel())
        .environmentObject(BluetoothService())
}
