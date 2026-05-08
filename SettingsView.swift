//
//  SettingsView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss
    
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // App Info
                        VStack(spacing: 16) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 64))
                                .foregroundColor(AppColors.accentGreen)
                            
                            Text("Speed Machine")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primaryBlack)
                            
                            Text("Version 1.0")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textMuted)
                        }
                        .padding()
                        
                        // Stats
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Statistics")
                                .font(.headline)
                                .foregroundColor(AppColors.primaryBlack)
                            
                            StatRow(title: "Current Day", value: "\(dataService.userProgress.currentDay)")
                            StatRow(title: "Total Putts", value: "\(dataService.userProgress.totalPutts)")
                            StatRow(title: "Combine High Score", value: "\(dataService.userProgress.combineHighScore)")
                            StatRow(title: "Completed Days", value: "\(dataService.getAllCompletedDays().count)")
                        }
                        .padding()
                        .cardStyle()
                        .padding(.horizontal)
                        
                        // Actions
                        VStack(spacing: 16) {
                            Button {
                                showResetConfirmation = true
                            } label: {
                                Text("Reset All Progress")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppColors.error)
                                    .cornerRadius(DesignConstants.cornerRadiusButton)
                            }
                        }
                        .padding(.horizontal)
                        
                        // About
                        VStack(alignment: .leading, spacing: 16) {
                            Text("About")
                                .font(.headline)
                                .foregroundColor(AppColors.primaryBlack)
                            
                            Text("Speed Machine is a putting training system designed to help you master speed control through progressive training.")
                                .font(.body)
                                .foregroundColor(AppColors.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .cardStyle()
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Reset Progress", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetProgress()
                }
            } message: {
                Text("This will delete all your progress, sessions, and scores. This action cannot be undone.")
            }
        }
    }
    
    private func resetProgress() {
        // Reset user progress
        dataService.userProgress.currentDay = 1
        dataService.userProgress.currentPhase = 1
        dataService.userProgress.unlockedZones = [1]
        dataService.userProgress.combineHighScore = 0
        dataService.userProgress.totalPutts = 0
        dataService.userProgress.updatedAt = Date()
        
        // Delete all sessions, completions, and games
        let context = dataService.container.viewContext
        
        // Delete all session data
        let sessionRequest: NSFetchRequest<NSFetchRequestResult> = SessionData.fetchRequest()
        let deleteSessionsRequest = NSBatchDeleteRequest(fetchRequest: sessionRequest)
        try? context.execute(deleteSessionsRequest)
        
        // Delete all day completions
        let completionRequest: NSFetchRequest<NSFetchRequestResult> = DayCompletionData.fetchRequest()
        let deleteCompletionsRequest = NSBatchDeleteRequest(fetchRequest: completionRequest)
        try? context.execute(deleteCompletionsRequest)
        
        // Delete all combine games
        let gameRequest: NSFetchRequest<NSFetchRequestResult> = CombineGameData.fetchRequest()
        let deleteGamesRequest = NSBatchDeleteRequest(fetchRequest: gameRequest)
        try? context.execute(deleteGamesRequest)
        
        // Delete all putt records
        let puttRequest: NSFetchRequest<NSFetchRequestResult> = PuttRecordData.fetchRequest()
        let deletePuttsRequest = NSBatchDeleteRequest(fetchRequest: puttRequest)
        try? context.execute(deletePuttsRequest)
        
        // Delete all combine shots
        let shotRequest: NSFetchRequest<NSFetchRequestResult> = CombineShotData.fetchRequest()
        let deleteShotsRequest = NSBatchDeleteRequest(fetchRequest: shotRequest)
        try? context.execute(deleteShotsRequest)
        
        try? context.save()
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataService.shared)
}
