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

    /// Set to true while a live training session is active so the device can rotate to landscape.
    static var allowLandscape: Bool = false

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UIWindow.appearance().backgroundColor = UIColor(AppColors.backgroundAlt)
        return true
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.allowLandscape ? .allButUpsideDown : .portrait
    }
}

struct ContentView: View {
    var body: some View {
        HomeView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.backgroundAlt.ignoresSafeArea())
    }
}
