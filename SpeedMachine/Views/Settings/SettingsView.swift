//
//  SettingsView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var statsService: StatsService
    @AppStorage("audioFeedbackEnabled") private var audioFeedbackEnabled = true
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled = true
    @State private var showResetStatsAlert = false
    @State private var showResetStatsConfirm = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()

                List {
                    // Feedback Settings
                    Section {
                        Toggle("Audio Feedback", isOn: $audioFeedbackEnabled)
                        Toggle("Haptic Feedback", isOn: $hapticFeedbackEnabled)
                    } header: {
                        Text("Feedback")
                    } footer: {
                        Text("Enable audio and haptic feedback for putts and achievements")
                    }

                    // Bluetooth Settings
                    Section {
                        NavigationLink {
                            BluetoothSettingsView()
                        } label: {
                            Label("Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    } header: {
                        Text("Device")
                    }

                    // Data Management
                    Section {
                        Button(role: .destructive) {
                            showResetStatsAlert = true
                        } label: {
                            Label("Reset Stats", systemImage: "arrow.counterclockwise")
                                .foregroundColor(AppColors.error)
                        }
                    } header: {
                        Text("Data")
                    } footer: {
                        Text("This resets your speed profiles and trend data. Training program progress is not affected.")
                    }

                    // App Info
                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(AppColors.textMuted)
                        }

                        HStack {
                            Text("Build")
                            Spacer()
                            Text("2026.01.25")
                                .foregroundColor(AppColors.textMuted)
                        }
                    } header: {
                        Text("About")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Speed Machine Training App")
                                .font(.caption)
                            Text("Created by Jarit Golf")
                                .font(.caption)
                            Text("© 2026 Jarit Golf. All rights reserved.")
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.textMuted)
                    }
                }
                .scrollContentBackground(.hidden)
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
            .alert("Reset Stats?", isPresented: $showResetStatsAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    showResetStatsConfirm = true
                }
            } message: {
                Text("This will erase all your speed profiles, accuracy history, and trend data. Your training program progress will not be affected.")
            }
            .alert("Are you sure?", isPresented: $showResetStatsConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Yes, Reset Everything", role: .destructive) {
                    statsService.resetAllStats()
                }
            } message: {
                Text("This cannot be undone. All stats data will be permanently deleted.")
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct BluetoothSettingsView: View {
    @EnvironmentObject var bluetoothService: BluetoothService

    var body: some View {
        ZStack {
            AppColors.backgroundAlt.ignoresSafeArea()

            List {
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(bluetoothService.connectionState.rawValue)
                            .foregroundColor(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textMuted)
                    }

                    if bluetoothService.isConnected {
                        HStack {
                            Text("Battery Level")
                            Spacer()
                            Text("\(bluetoothService.batteryLevel)%")
                                .foregroundColor(AppColors.textMuted)
                        }
                    }
                } header: {
                    Text("Connection Status")
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        TroubleshootRow(
                            icon: "1.circle.fill",
                            text: "Make sure Bluetooth is enabled on your device"
                        )
                        TroubleshootRow(
                            icon: "2.circle.fill",
                            text: "Enable Bluetooth on Speed Machine device"
                        )
                        TroubleshootRow(
                            icon: "3.circle.fill",
                            text: "Set device to Speed Mode"
                        )
                        TroubleshootRow(
                            icon: "4.circle.fill",
                            text: "Tap 'Scan for Devices' on connection screen"
                        )
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Troubleshooting")
                } footer: {
                    Text("If you're having trouble connecting, try turning Bluetooth off and on again on both devices.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoDetailRow(label: "Service UUID", value: BLEConstants.serviceUUID)
                        InfoDetailRow(label: "Device Name", value: BLEConstants.deviceName)
                    }
                } header: {
                    Text("Technical Details")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Bluetooth Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TroubleshootRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accentGreen)
                .font(.headline)

            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.primaryBlack)
        }
    }
}

struct InfoDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textMuted)

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(AppColors.primaryBlack)
        }
        .padding(.vertical, 4)
    }
}
