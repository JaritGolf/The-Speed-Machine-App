//
//  SettingsView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var dataService: DataService
    @AppStorage("audioFeedbackEnabled") private var audioFeedbackEnabled = true
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled = true
    @AppStorage("liveViewTheme") private var liveViewThemeRaw: String = LiveViewTheme.light.rawValue
    @State private var showResetConfirm = false
    @State private var showBluetooth = false
    @State private var debugTrack: Int = 1
    @State private var showTrackSaved = false

    private var liveViewTheme: Binding<LiveViewTheme> {
        Binding(
            get: { LiveViewTheme(rawValue: liveViewThemeRaw) ?? .light },
            set: { liveViewThemeRaw = $0.rawValue }
        )
    }

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
                    Text("SETTINGS")
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
                        // FEEDBACK section
                        settingsHeader("FEEDBACK")

                        settingsToggleRow(
                            label: "AUDIO FEEDBACK",
                            binding: $audioFeedbackEnabled
                        )
                        Divider().overlay(AppColors.border).padding(.leading, 22)

                        settingsToggleRow(
                            label: "HAPTIC FEEDBACK",
                            binding: $hapticFeedbackEnabled
                        )

                        settingsFooter("Enable audio and haptic cues during training sessions.")

                        Divider().overlay(AppColors.border)

                        // LIVE VIEW section
                        settingsHeader("LIVE VIEW")

                        HStack {
                            Text("THEME")
                                .font(.custom("Inter-SemiBold", size: 13))
                                .foregroundColor(.black)
                            Spacer()
                            Picker("Theme", selection: liveViewTheme) {
                                ForEach(LiveViewTheme.allCases) { theme in
                                    Text(theme.displayName).tag(theme)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)

                        settingsFooter("Dark is recommended for the 5–6 ft viewing distance during training.")

                        Divider().overlay(AppColors.border)

                        // DEVICE section
                        settingsHeader("DEVICE")

                        Button {
                            showBluetooth = true
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textSubdued)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("BLUETOOTH")
                                        .font(.custom("Inter-SemiBold", size: 13))
                                        .foregroundColor(.black)
                                    Text(bluetoothService.isConnected
                                         ? "CONNECTED\(bluetoothService.batteryLevel > 0 ? " · \(bluetoothService.batteryLevel)%" : "")"
                                         : "NOT CONNECTED")
                                        .font(.custom("Inter-Bold", size: 10))
                                        .kerning(1.0)
                                        .foregroundColor(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textSubdued)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColors.textSubdued)
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                        }

                        Divider().overlay(AppColors.border)

                        // DATA section
                        settingsHeader("DATA")

                        Button {
                            showResetConfirm = true
                        } label: {
                            HStack {
                                Text("RESET STATS")
                                    .font(.custom("Inter-SemiBold", size: 13))
                                    .foregroundColor(AppColors.error)
                                Spacer()
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                        }

                        settingsFooter("Resets speed profiles and trend data. Training program progress is not affected.")

                        Divider().overlay(AppColors.border)

                        // ABOUT section
                        settingsHeader("ABOUT")

                        HStack {
                            Text("VERSION")
                                .font(.custom("Inter-SemiBold", size: 13))
                                .foregroundColor(.black)
                            Spacer()
                            Text("1.0.0")
                                .font(.custom("Inter-Regular", size: 13))
                                .foregroundColor(AppColors.textMuted)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)

                        Divider().overlay(AppColors.border).padding(.leading, 22)

                        HStack {
                            Text("PROGRAM SYNC")
                                .font(.custom("Inter-SemiBold", size: 13))
                                .foregroundColor(.black)
                            Spacer()
                            Text(UserDefaults.standard.string(forKey: NetworkService.statusKey) ?? "—")
                                .font(.custom("Inter-Regular", size: 11))
                                .foregroundColor(AppColors.textSubdued)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)

                        Divider().overlay(AppColors.border).padding(.leading, 22)

                        HStack {
                            Text("ICLOUD SYNC")
                                .font(.custom("Inter-SemiBold", size: 13))
                                .foregroundColor(.black)
                            Spacer()
                            iCloudSyncStatusView
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)

                        Divider().overlay(AppColors.border)

                        // DEBUG section
                        settingsHeader("DEBUG")

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("CURRENT TRACK")
                                    .font(.custom("Inter-SemiBold", size: 13))
                                    .foregroundColor(.black)
                                if showTrackSaved {
                                    Text("Saved")
                                        .font(.custom("Inter-Regular", size: 11))
                                        .foregroundColor(AppColors.accentGreen)
                                        .transition(.opacity)
                                }
                            }
                            Spacer()
                            Stepper(value: $debugTrack, in: 1...30) {
                                Text("\(debugTrack)")
                                    .font(.custom("Inter-Bold", size: 15))
                                    .foregroundColor(.black)
                                    .frame(minWidth: 28, alignment: .center)
                            }
                            .onChange(of: debugTrack) { _, newValue in
                                dataService.updateProgress(currentTrack: newValue, phase: 1)
                                withAnimation(.easeInOut(duration: 0.2)) { showTrackSaved = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation(.easeInOut(duration: 0.2)) { showTrackSaved = false }
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)

                        settingsFooter("Override current track for testing. Does not affect completed track history.")

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showBluetooth) {
            BluetoothSettingsView()
        }
        .onAppear {
            debugTrack = Int(dataService.userProgress.currentDay)
        }
        // Reset confirmation overlay
        .overlay {
            if showResetConfirm {
                ResetStatsModal(isPresented: $showResetConfirm) {
                    statsService.resetAllStats()
                }
            }
        }
    }

    @ViewBuilder
    private var iCloudSyncStatusView: some View {
        switch dataService.cloudKitSyncStatus {
        case .idle:
            Text("Ready")
                .font(.custom("Inter-Regular", size: 11))
                .foregroundColor(AppColors.textSubdued)
        case .syncing:
            HStack(spacing: 5) {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(AppColors.textSubdued)
                Text("Syncing…")
                    .font(.custom("Inter-Regular", size: 11))
                    .foregroundColor(AppColors.textSubdued)
            }
        case .synced:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.accentGreen)
                Text("Synced")
                    .font(.custom("Inter-Bold", size: 11))
                    .foregroundColor(AppColors.accentGreen)
            }
        case .error:
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.error)
                Text("Error")
                    .font(.custom("Inter-Bold", size: 11))
                    .foregroundColor(AppColors.error)
            }
        }
    }

    private func settingsHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.custom("Inter-Bold", size: 10))
                .kerning(2.5)
                .foregroundColor(AppColors.textSubdued)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private func settingsToggleRow(label: String, binding: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.custom("Inter-SemiBold", size: 13))
                .foregroundColor(.black)
            Spacer()
            Toggle("", isOn: binding)
                .tint(AppColors.accentGreen)
                .labelsHidden()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private func settingsFooter(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.custom("Inter-Regular", size: 12))
                .foregroundColor(AppColors.textSubdued)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }
}

// MARK: - Reset Stats Modal

struct ResetStatsModal: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.50)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("Are you sure?")
                        .font(.custom("Inter-Black", size: 20))
                        .foregroundColor(.black)

                    Text("This will erase all your speed profiles, accuracy history, and trend data. Your training program progress will not be affected.")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(AppColors.textMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)

                Divider().overlay(AppColors.border)

                // YES button — filled red
                Button {
                    onConfirm()
                    isPresented = false
                } label: {
                    Text("Yes, Reset Everything")
                        .font(.custom("Inter-Bold", size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.error)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Cancel button — plain text
                Button {
                    isPresented = false
                } label: {
                    Text("Cancel")
                        .font(.custom("Inter-Medium", size: 15))
                        .foregroundColor(.black)
                        .padding(.vertical, 14)
                }
                .padding(.bottom, 8)
            }
            .background(Color.white)
            .cornerRadius(16)
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Bluetooth Settings View

struct BluetoothSettingsView: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    @Environment(\.dismiss) var dismiss

    private let troubleshootSteps: [String] = [
        "Make sure Bluetooth is enabled on your iPhone",
        "Enable Bluetooth on your The Speed Machine device",
        "Set The Speed Machine to Speed Mode",
        "Tap \"Scan for Devices\" on the connection screen"
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("SETTINGS")
                                .font(.custom("Inter-Bold", size: 12))
                                .kerning(1.5)
                        }
                        .foregroundColor(.black)
                    }
                    Spacer()
                    Text("BLUETOOTH")
                        .font(.custom("Inter-Bold", size: 13))
                        .kerning(2.5)
                        .foregroundColor(.black)
                    Spacer()
                    Color.clear.frame(width: 70, height: 24)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 12)

                Divider().overlay(AppColors.border)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // CONNECTION STATUS
                        sectionHeader("CONNECTION STATUS")

                        HStack {
                            Text("STATUS")
                                .font(.custom("Inter-SemiBold", size: 13))
                                .foregroundColor(.black)
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textSubdued)
                                    .frame(width: 7, height: 7)
                                Text(bluetoothService.isConnected ? "Connected" : "Not Connected")
                                    .font(.custom("Inter-Bold", size: 12))
                                    .foregroundColor(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textSubdued)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)

                        if bluetoothService.isConnected && bluetoothService.batteryLevel > 0 {
                            Divider().overlay(AppColors.border).padding(.leading, 22)
                            HStack {
                                Text("BATTERY LEVEL")
                                    .font(.custom("Inter-SemiBold", size: 13))
                                    .foregroundColor(.black)
                                Spacer()
                                Text("\(bluetoothService.batteryLevel)%")
                                    .font(.custom("Inter-Regular", size: 13))
                                    .foregroundColor(AppColors.textMuted)
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                        }

                        Divider().overlay(AppColors.border)

                        // TROUBLESHOOTING
                        sectionHeader("TROUBLESHOOTING")

                        ForEach(Array(troubleshootSteps.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.accentGreen)
                                        .frame(width: 24, height: 24)
                                    Text("\(idx + 1)")
                                        .font(.custom("Inter-Bold", size: 11))
                                        .foregroundColor(.white)
                                }

                                Text(step)
                                    .font(.custom("Inter-Regular", size: 13))
                                    .foregroundColor(.black)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer()
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)

                            if idx < troubleshootSteps.count - 1 {
                                Divider().overlay(AppColors.border).padding(.leading, 60)
                            }
                        }

                        Text("If you're having trouble, try toggling Bluetooth off and on again on both devices.")
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(AppColors.textSubdued)
                            .padding(.horizontal, 22)
                            .padding(.top, 8)
                            .padding(.bottom, 16)

                        Divider().overlay(AppColors.border)

                        // TECHNICAL DETAILS
                        sectionHeader("TECHNICAL DETAILS")

                        techRow(label: "SERVICE UUID", value: BLEConstants.serviceUUID)
                        Divider().overlay(AppColors.border).padding(.leading, 22)
                        techRow(label: "DEVICE NAME", value: BLEConstants.deviceName)

                        Divider().overlay(AppColors.border)

                        Spacer(minLength: 40)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.custom("Inter-Bold", size: 10))
                .kerning(2.5)
                .foregroundColor(AppColors.textSubdued)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private func techRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.custom("Inter-Bold", size: 10))
                .kerning(1.5)
                .foregroundColor(AppColors.textSubdued)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }
}
