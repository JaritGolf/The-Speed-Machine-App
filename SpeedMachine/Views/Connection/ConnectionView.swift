//
//  ConnectionView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()

                VStack(spacing: 24) {
                    if bluetoothService.isConnected {
                        // Connected State
                        ConnectedStateView()
                    } else {
                        // Not Connected State
                        DisconnectedStateView()
                    }
                }
                .padding()
            }
            .navigationTitle("Device Connection")
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

struct ConnectedStateView: View {
    @EnvironmentObject var bluetoothService: BluetoothService

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Connection Status Icon
            ZStack {
                Circle()
                    .fill(AppColors.accentLight)
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.accentGreen)
            }

            VStack(spacing: 8) {
                Text("Connected")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryBlack)

                Text(BLEConstants.deviceName)
                    .font(.headline)
                    .foregroundColor(AppColors.textMuted)
            }

            // Battery Level
            HStack(spacing: 12) {
                Image(systemName: batteryIcon)
                    .font(.title3)
                    .foregroundColor(batteryColor)

                Text("\(bluetoothService.batteryLevel)%")
                    .font(.headline)
                    .foregroundColor(AppColors.textMuted)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )

            Spacer()

            // Disconnect Button
            Button {
                bluetoothService.disconnect()
            } label: {
                Text("Disconnect")
                    .secondaryButtonStyle()
            }

            // Troubleshooting
            Text("Make sure device is in Speed Mode")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    var batteryIcon: String {
        let level = bluetoothService.batteryLevel
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }

    var batteryColor: Color {
        let level = bluetoothService.batteryLevel
        if level > 25 { return AppColors.accentGreen }
        return AppColors.error
    }
}

struct DisconnectedStateView: View {
    @EnvironmentObject var bluetoothService: BluetoothService

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Instructions
            VStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.textMuted)

                Text("Connect to Speed Machine")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryBlack)

                VStack(alignment: .leading, spacing: 12) {
                    InstructionRow(number: 1, text: "Enable Bluetooth on device")
                    InstructionRow(number: 2, text: "Set device to Speed Mode")
                    InstructionRow(number: 3, text: "Tap 'Scan for Devices'")
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }

            // Device List
            if bluetoothService.isScanning || !bluetoothService.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Devices")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryBlack)

                    if bluetoothService.discoveredDevices.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("Scanning...")
                                .foregroundColor(AppColors.textMuted)
                            Spacer()
                        }
                        .padding()
                    } else {
                        ForEach(bluetoothService.discoveredDevices, id: \.identifier) { device in
                            Button {
                                bluetoothService.connect(to: device)
                            } label: {
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .font(.caption)
                                        .foregroundColor(AppColors.bleBlue)

                                    Text(device.name ?? "Unknown Device")
                                        .foregroundColor(AppColors.primaryBlack)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(AppColors.textMuted)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Scan Button
            Button {
                if bluetoothService.isScanning {
                    bluetoothService.stopScanning()
                } else {
                    bluetoothService.startScanning()
                }
            } label: {
                Text(bluetoothService.isScanning ? "Stop Scanning" : "Scan for Devices")
                    .primaryButtonStyle()
            }

            // Error Message
            if let error = bluetoothService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(AppColors.error)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accentGreen)
                    .frame(width: 28, height: 28)

                Text("\(number)")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.primaryBlack)

            Spacer()
        }
    }
}
