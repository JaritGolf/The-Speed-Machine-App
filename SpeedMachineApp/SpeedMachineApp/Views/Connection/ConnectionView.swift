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
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                scrollContent
                bottomBar
            }
        }
        .onAppear {
            if !bluetoothService.isConnected && !bluetoothService.isScanning {
                bluetoothService.startScanning()
            }
        }
        .onDisappear {
            if bluetoothService.isScanning {
                bluetoothService.stopScanning()
            }
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                chapterHeader
                headline
                stepsSection
                    .padding(.top, 28)
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Chapter Header

    private var chapterHeader: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text("02.")
                .font(.custom("Inter-Black", size: 110))
                .foregroundColor(.black)
                .tracking(-5)
                .lineLimit(1)
                .padding(.top, 60)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text("PAIR")
                        .font(.custom("Inter-Bold", size: 11))
                        .kerning(2.5)
                        .foregroundColor(.black)
                    Spacer()
                    Image("SpeedMachineLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 35)
                }
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)
            .padding(.top, 60)
        }
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connect your\nmachine.")
                .font(.custom("Inter-Black", size: 40))
                .foregroundColor(.black)
                .lineSpacing(2)
                .tracking(-1)
                .fixedSize(horizontal: false, vertical: true)

            Text("Follow these steps to get started.")
                .font(.custom("Inter-Regular", size: 14))
                .foregroundColor(AppColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 28)
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(spacing: 0) {
            pairingStep(
                number: 1,
                state: .active,
                title: "Turn it on",
                subtitle: "Press the power button on the top right corner of your The Speed Machine."
            )

            stepConnector(active: true)

            pairingStep(
                number: 2,
                state: .active,
                title: "Set Speed Mode",
                subtitle: "On the device screen, press Speed to switch into Speed Mode."
            )

            stepConnector(active: !bluetoothService.isConnected)

            if bluetoothService.isConnected {
                pairingStep(
                    number: 3,
                    state: .done,
                    title: "Device found!",
                    subtitle: nil
                )
                deviceFoundCard
            } else {
                pairingStep(
                    number: 3,
                    state: .waiting,
                    title: "Waiting for device...",
                    subtitle: "The app will recognize your machine automatically."
                )
                listeningIndicator
            }
        }
    }

    private enum StepState { case active, waiting, done }

    private func pairingStep(number: Int, state: StepState, title: String, subtitle: String?) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(state == .active ? Color.black
                          : state == .done ? AppColors.accentGreen
                          : Color(hex: "f0f0f0"))
                    .frame(width: 32, height: 32)

                if state == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.custom("Inter-ExtraBold", size: 14))
                        .foregroundColor(state == .active ? .white : Color(hex: "c8c8c8"))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Inter-Bold", size: 16))
                    .foregroundColor(state == .waiting ? AppColors.textSubdued : .black)

                if let sub = subtitle {
                    Text(sub)
                        .font(.custom("Inter-Regular", size: 13))
                        .foregroundColor(AppColors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
    }

    private func stepConnector(active: Bool) -> some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(active ? Color.black.opacity(0.15) : Color(hex: "f0f0f0"))
                .frame(width: 1, height: 24)
                .padding(.leading, 15)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var listeningIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AppColors.accentGreen)
                .frame(width: 9, height: 9)
                .shadow(color: AppColors.accentGreen.opacity(0.5), radius: 4)

            Text("LISTENING")
                .font(.custom("Inter-Bold", size: 11))
                .kerning(2.5)
                .foregroundColor(AppColors.accentGreen)
        }
        .padding(.top, 12)
        .padding(.leading, 48)
    }

    private var deviceFoundCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppColors.accentGreen)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(BLEConstants.deviceName)
                    .font(.custom("Inter-Bold", size: 15))
                    .foregroundColor(.black)
                Text("SM-A47B · CONNECTED")
                    .font(.custom("Inter-Bold", size: 10))
                    .kerning(1.5)
                    .foregroundColor(AppColors.textMuted)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppColors.accentGreen.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.accentGreen.opacity(0.25), lineWidth: 1.5)
        )
        .cornerRadius(12)
        .padding(.top, 12)
        .padding(.leading, 48)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 14) {
            if bluetoothService.isConnected {
                Button { dismiss() } label: {
                    Text("Begin Training →")
                        .font(.custom("Inter-Bold", size: 17))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(AppColors.accentGreen)
                        .clipShape(Capsule())
                }
            }

            Button { dismiss() } label: {
                Text("Having trouble?")
                    .font(.custom("Inter-Medium", size: 13))
                    .foregroundColor(AppColors.textMuted)
                    .underline()
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(Color.white)
    }
}
