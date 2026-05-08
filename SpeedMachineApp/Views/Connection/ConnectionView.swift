//
//  ConnectionView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI
import CoreBluetooth

struct ConnectionView: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            AppColors.backgroundAlt.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                            Text("Back")
                                .font(.body)
                        }
                        .foregroundColor(AppColors.primaryBlack)
                    }

                    Spacer()

                    Text("Device")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryBlack)

                    Spacer()

                    // Invisible spacer to balance the back button
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("Back")
                            .font(.body)
                    }
                    .opacity(0)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .fill(AppColors.border)
                        .frame(height: 1),
                    alignment: .bottom
                )

                ScrollView {
                    VStack(spacing: 16) {
                        if bluetoothService.isConnected {
                            ConnectedStateView(dismiss: dismiss)
                        } else {
                            DisconnectedStateView()
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct ConnectedStateView: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    var dismiss: DismissAction

    var body: some View {
        VStack(spacing: 16) {
            // Status card
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(AppColors.accentGreen.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.accentGreen)
                }

                VStack(spacing: 4) {
                    Text("Connected")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryBlack)

                    Text(BLEConstants.deviceName)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textMuted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )

            // Battery card
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(batteryColor.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: batteryIcon)
                        .font(.title3)
                        .foregroundColor(batteryColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Battery Level")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryBlack)

                    Text("\(bluetoothService.batteryLevel)%")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                Text("\(bluetoothService.batteryLevel)%")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(batteryColor)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )

            // Device info card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.bleBlue.opacity(0.15))
                            .frame(width: 50, height: 50)

                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(AppColors.bleBlue)
                    }

                    Text("Device Info")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryBlack)

                    Spacer()
                }

                VStack(spacing: 0) {
                    DeviceInfoRow(label: "Device", value: BLEConstants.deviceName)
                    Divider().padding(.horizontal)
                    DeviceInfoRow(label: "Status", value: "Connected", valueColor: AppColors.accentGreen)
                    Divider().padding(.horizontal)
                    DeviceInfoRow(label: "Mode", value: "Speed Mode")
                }
                .background(AppColors.backgroundAlt)
                .cornerRadius(8)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )

            // Prominent back button
            Button {
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left")
                        .font(.body.weight(.semibold))
                    Text("Back to Home")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.accentGreen)
                .cornerRadius(12)
            }

            // Disconnect button
            Button {
                bluetoothService.disconnect()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle")
                        .font(.body)
                    Text("Disconnect")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(AppColors.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.error.opacity(0.3), lineWidth: 1)
                )
            }

            Text("Make sure device is in Speed Mode")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .padding(.top, 4)
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
        VStack(spacing: 16) {
            // Hero card with icon and instructions
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(AppColors.bleBlue.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.bleBlue)
                }

                VStack(spacing: 4) {
                    Text("Connect to Speed Machine")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryBlack)

                    Text("Follow the steps below to pair your device")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textMuted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )

            // Instructions card
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accentGreen.opacity(0.15))
                            .frame(width: 50, height: 50)

                        Image(systemName: "list.number")
                            .font(.title3)
                            .foregroundColor(AppColors.accentGreen)
                    }

                    Text("Setup Steps")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryBlack)

                    Spacer()
                }
                .padding(.bottom, 12)

                VStack(spacing: 0) {
                    InstructionRow(number: 1, text: "Enable Bluetooth on device")
                    Divider().padding(.leading, 52)
                    InstructionRow(number: 2, text: "Set device to Speed Mode")
                    Divider().padding(.leading, 52)
                    InstructionRow(number: 3, text: "Tap 'Scan for Devices' below")
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )

            // Device List
            if bluetoothService.isScanning || !bluetoothService.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.bleBlue.opacity(0.15))
                                .frame(width: 50, height: 50)

                            Image(systemName: "magnifyingglass")
                                .font(.title3)
                                .foregroundColor(AppColors.bleBlue)
                        }

                        Text("Available Devices")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryBlack)

                        Spacer()

                        if bluetoothService.isScanning {
                            ProgressView()
                                .tint(AppColors.bleBlue)
                        }
                    }

                    if bluetoothService.discoveredDevices.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                ProgressView()
                                    .tint(AppColors.bleBlue)
                                Text("Scanning...")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textMuted)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    } else {
                        ForEach(bluetoothService.discoveredDevices, id: \.identifier) { device in
                            Button {
                                bluetoothService.connect(to: device)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(AppColors.bleBlue.opacity(0.15))
                                            .frame(width: 36, height: 36)

                                        Image(systemName: "wave.3.right")
                                            .font(.caption)
                                            .foregroundColor(AppColors.bleBlue)
                                    }

                                    Text(device.name ?? "Unknown Device")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.primaryBlack)

                                    Spacer()

                                    Text("Connect")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.accentGreen)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(AppColors.accentGreen.opacity(0.15))
                                        .cornerRadius(6)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(AppColors.backgroundAlt)
                                .cornerRadius(8)
                            }
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

            // Scan Button
            Button {
                if bluetoothService.isScanning {
                    bluetoothService.stopScanning()
                } else {
                    bluetoothService.startScanning()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: bluetoothService.isScanning ? "stop.circle" : "magnifyingglass")
                        .font(.body.weight(.semibold))
                    Text(bluetoothService.isScanning ? "Stop Scanning" : "Scan for Devices")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.accentGreen)
                .cornerRadius(12)
            }

            // Error Message
            if let error = bluetoothService.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.error)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppColors.error)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppColors.error.opacity(0.08))
                .cornerRadius(8)
            }
        }
    }
}

struct DeviceInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = AppColors.primaryBlack

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.textMuted)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accentGreen.opacity(0.15))
                    .frame(width: 28, height: 28)

                Text("\(number)")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundColor(AppColors.accentGreen)
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.primaryBlack)

            Spacer()
        }
        .padding(.vertical, 6)
    }
}
