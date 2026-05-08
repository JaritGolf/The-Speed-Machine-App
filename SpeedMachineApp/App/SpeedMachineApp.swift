//
//  SpeedMachineApp.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI
import UIKit

@main
struct SpeedMachineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var bluetoothService = BluetoothService()
    @StateObject private var trainingViewModel = TrainingViewModel()
    @StateObject private var combineViewModel = CombineViewModel()
    @StateObject private var dataService = DataService.shared
    @StateObject private var statsService = StatsService.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()
                ContentView()
            }
            .environmentObject(bluetoothService)
            .environmentObject(trainingViewModel)
            .environmentObject(combineViewModel)
            .environmentObject(dataService)
            .environmentObject(statsService)
            .onAppear {
                // One-time migration for existing users
                statsService.migrateExistingData()
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UIWindow.appearance().backgroundColor = UIColor(AppColors.backgroundAlt)
        return true
    }
}

struct ContentView: View {
    var body: some View {
        HomeView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.backgroundAlt.ignoresSafeArea())
    }
}
