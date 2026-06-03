//
//  SettingsView.swift
//  SpeedMachine
//
//  Whoop minimal settings (mockups 21–23).
//

import SwiftUI
import Combine

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var dataService: DataService

    @AppStorage("audioFeedbackEnabled") private var audioFeedbackEnabled = true
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled = true
    @AppStorage("liveViewTheme") private var liveViewThemeRaw: String = LiveViewTheme.light.rawValue
    @State private var showResetModal = false
    @State private var showRestoreModal = false
    @State private var showBackupSaved = false
    @State private var showRestoreDone = false
    @State private var debugTrack: Int = 1
    @State private var showTrackSaved = false
    @StateObject private var adminVersion = AdminVersionService()

    private var themeBinding: Binding<LiveViewTheme> {
        Binding(
            get: { LiveViewTheme(rawValue: liveViewThemeRaw) ?? .light },
            set: { liveViewThemeRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    SettingsHeader(title: "SETTINGS", leading: .close) { dismiss() }

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsSectionLabel("FEEDBACK")
                            SettingsToggleRow(title: "AUDIO FEEDBACK", isOn: $audioFeedbackEnabled)
                            SettingsToggleRow(title: "HAPTIC FEEDBACK", isOn: $hapticFeedbackEnabled)
                            SettingsFooter("Enable audio and haptic cues for putts and achievements.")

                            SettingsSectionLabel("LIVE VIEW")
                            themeRow
                            SettingsFooter("Dark is recommended for the 5–6 ft viewing distance.")

                            SettingsSectionLabel("DEVICE")
                            NavigationLink { BluetoothSettingsView() } label: { bluetoothRow }
                                .buttonStyle(.plain)

                            SettingsSectionLabel("DATA")
                            Button { showResetModal = true } label: {
                                SettingsRow {
                                    Text("RESET STATS")
                                        .modifier(RowLabel(color: AppColors.error))
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            SettingsFooter("Resets speed profiles and trend data. Training program progress is not affected.")

                            SettingsSectionLabel("ICLOUD BACKUP")
                            SettingsRow {
                                Text("STATUS").modifier(RowLabel())
                                Spacer()
                                iCloudSyncValue
                            }
                            SettingsRow {
                                Text("LAST BACKED UP").modifier(RowLabel())
                                Spacer()
                                Text(lastBackupText).modifier(SettingsValue())
                            }
                            Button { backUpNow() } label: {
                                SettingsRow {
                                    Text("BACK UP NOW").modifier(RowLabel(color: AppColors.accentGreen))
                                    Spacer()
                                    if showBackupSaved {
                                        Text("Backed up ✓")
                                            .font(.custom("Inter-Bold", size: 11))
                                            .foregroundColor(AppColors.accentGreen)
                                            .transition(.opacity)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            Button { showRestoreModal = true } label: {
                                SettingsRow {
                                    Text("RESTORE FROM ICLOUD").modifier(RowLabel())
                                    Spacer()
                                    if showRestoreDone {
                                        Text("Restored ✓")
                                            .font(.custom("Inter-Bold", size: 11))
                                            .foregroundColor(AppColors.accentGreen)
                                            .transition(.opacity)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            SettingsFooter("Your progress, stats, session history and combine scores are backed up to iCloud automatically and restored if you reinstall. Putt-by-putt detail restores when iCloud finishes syncing.")

                            SettingsSectionLabel("ABOUT")
                            SettingsRow {
                                Text("VERSION").modifier(RowLabel())
                                Spacer()
                                Text("1.0.0").modifier(SettingsValue())
                            }
                            SettingsRow {
                                Text("BUILD").modifier(RowLabel())
                                Spacer()
                                Text("2026.01.25").modifier(SettingsValue())
                            }
                            SettingsRow {
                                Text("PROGRAM VERSION").modifier(RowLabel())
                                Spacer()
                                Text(adminVersion.display).modifier(SettingsValue())
                            }
                            SettingsRow {
                                Text("ICLOUD SYNC").modifier(RowLabel())
                                Spacer()
                                iCloudSyncValue
                            }
                            SettingsFooter("Program Version is the latest training program published from the Speed Machine admin panel. The Speed Machine Training App · Jarit Golf · © 2026 Jarit Golf. All rights reserved.")

                            SettingsSectionLabel("DEBUG")
                            SettingsRow {
                                Text("ICLOUD ACCOUNT").modifier(RowLabel())
                                Spacer()
                                Text(dataService.cloudKitAccountStatus)
                                    .font(.custom("Inter-Medium", size: 12))
                                    .foregroundColor(dataService.cloudKitAccountStatus.contains("✓") ? AppColors.accentGreen : AppColors.error)
                                    .multilineTextAlignment(.trailing)
                            }
                            SettingsRow {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("CURRENT TRACK").modifier(RowLabel())
                                    if showTrackSaved {
                                        Text("Saved")
                                            .font(.custom("Inter-Bold", size: 11))
                                            .foregroundColor(AppColors.accentGreen)
                                            .transition(.opacity)
                                    }
                                }
                                Spacer()
                                Stepper(value: $debugTrack, in: 1...30) {
                                    Text("\(debugTrack)")
                                        .font(.custom("Inter-Bold", size: 15))
                                        .foregroundColor(.black)
                                }
                                .onChange(of: debugTrack) { _, newValue in
                                    dataService.updateProgress(currentDay: newValue, phase: 1)
                                    withAnimation(.easeInOut(duration: 0.2)) { showTrackSaved = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation(.easeInOut(duration: 0.2)) { showTrackSaved = false }
                                    }
                                }
                            }
                            SettingsFooter("Override current track for testing. Does not affect completed track history.")
                        }
                        .padding(.bottom, 24)
                    }
                }

                if showResetModal {
                    ResetStatsModal(
                        onConfirm: { statsService.resetAllStats(); showResetModal = false },
                        onCancel: { showResetModal = false }
                    )
                }

                if showRestoreModal {
                    RestoreModal(
                        onConfirm: { restoreFromICloud(); showRestoreModal = false },
                        onCancel: { showRestoreModal = false }
                    )
                }
            }
            .navigationBarHidden(true)
            .task { await adminVersion.fetch() }
            .onAppear { debugTrack = Int(dataService.userProgress.currentDay) }
        }
    }

    private var lastBackupText: String {
        guard let date = dataService.lastBackupDate else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func backUpNow() {
        dataService.backUpNowToICloud(statsService: statsService)
        withAnimation(.easeInOut(duration: 0.2)) { showBackupSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) { showBackupSaved = false }
        }
    }

    private func restoreFromICloud() {
        dataService.restoreFromICloudNow(statsService: statsService)
        withAnimation(.easeInOut(duration: 0.2)) { showRestoreDone = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) { showRestoreDone = false }
        }
    }

    @ViewBuilder
    private var iCloudSyncValue: some View {
        switch dataService.cloudKitSyncStatus {
        case .idle:
            Text("Ready").modifier(SettingsValue())
        case .syncing:
            HStack(spacing: 5) {
                ProgressView().scaleEffect(0.7).tint(AppColors.textSubdued)
                Text("Syncing…").modifier(SettingsValue())
            }
        case .synced:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11)).foregroundColor(AppColors.accentGreen)
                Text("Synced")
                    .font(.custom("Inter-Bold", size: 11)).foregroundColor(AppColors.accentGreen)
            }
        case .error:
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11)).foregroundColor(AppColors.error)
                Text("Error")
                    .font(.custom("Inter-Bold", size: 11)).foregroundColor(AppColors.error)
            }
        }
    }

    private var themeRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THEME").modifier(RowLabel())
            Picker("Theme", selection: themeBinding) {
                Text("Dark").tag(LiveViewTheme.dark)
                Text("Light").tag(LiveViewTheme.light)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }

    private var bluetoothRow: some View {
        SettingsRow {
            VStack(alignment: .leading, spacing: 5) {
                Text("BLUETOOTH").modifier(RowLabel())
                HStack(spacing: 6) {
                    Circle()
                        .fill(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textSubdued)
                        .frame(width: 8, height: 8)
                    Text(bluetoothService.isConnected ? "CONNECTED · \(bluetoothService.batteryLevel)%" : "NOT CONNECTED")
                        .font(.custom("Inter-Bold", size: 11))
                        .kerning(1.2)
                        .foregroundColor(AppColors.textMuted)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(AppColors.textSubdued)
        }
    }
}

// MARK: - Admin program version

/// Fetches the latest published training-program version from the Speed Machine
/// admin backend, purely for display in Settings.
@MainActor
final class AdminVersionService: ObservableObject {
    @Published var display: String = "Checking…"

    private let versionURL = "https://speed-machine-admin.vercel.app/api/program/version"

    func fetch() async {
        guard let url = URL(string: versionURL) else { display = "Unavailable"; return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                display = "Unavailable"; return
            }
            let decoded = try JSONDecoder().decode(VersionResponse.self, from: data)
            let date = String(decoded.publishedAt.prefix(10))
            display = "v\(decoded.version) · \(date)"
        } catch {
            display = "Offline"
        }
    }

    private struct VersionResponse: Decodable {
        let version: String
        let publishedAt: String
    }
}

// MARK: - Reusable settings pieces

private struct SettingsHeader: View {
    enum Leading { case close, back }
    let title: String
    let leading: Leading
    let action: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.custom("Inter-Bold", size: 16))
                .kerning(3)
                .foregroundColor(.black)
            HStack {
                Button(action: action) {
                    Image(systemName: leading == .close ? "xmark" : "arrow.left")
                        .font(.system(size: leading == .close ? 18 : 22, weight: .regular))
                        .foregroundColor(.black)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .bottom)
    }
}

private struct SettingsSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.custom("Inter-Bold", size: 11))
            .kerning(2.2)
            .foregroundColor(AppColors.textSubdued)
            .padding(.horizontal, 32)
            .padding(.top, 22)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsFooter: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.custom("Inter-Regular", size: 12))
            .foregroundColor(AppColors.textSubdued)
            .lineSpacing(4)
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsRow<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(spacing: 12) { content() }
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }
}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        SettingsRow {
            Text(title).modifier(RowLabel())
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppColors.accentGreen)
        }
    }
}

private struct RowLabel: ViewModifier {
    var color: Color = AppColors.textSubdued
    func body(content: Content) -> some View {
        content
            .font(.custom("Inter-Bold", size: 11))
            .kerning(2.2)
            .foregroundColor(color)
    }
}

private struct SettingsValue: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("Inter-Medium", size: 13))
            .foregroundColor(AppColors.textSubdued)
    }
}

// MARK: - Reset modal (mockup 23)

private struct ResetStatsModal: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.48).ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                Text("Are you sure?")
                    .font(.custom("Inter-Bold", size: 17))
                    .foregroundColor(.black)
                    .padding(.bottom, 8)
                Text("This cannot be undone. All speed profiles, accuracy history, and trend data will be permanently deleted.")
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(AppColors.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.bottom, 24)

                Button(action: onConfirm) {
                    Text("Yes, Reset Everything")
                        .font(.custom("Inter-Bold", size: 15))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(AppColors.error)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.bottom, 8)

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.custom("Inter-Medium", size: 15))
                        .foregroundColor(AppColors.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Restore modal

private struct RestoreModal: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.48).ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                Text("Restore from iCloud?")
                    .font(.custom("Inter-Bold", size: 17))
                    .foregroundColor(.black)
                    .padding(.bottom, 8)
                Text("This pulls your latest iCloud backup — progress, stats, session history and combine scores — into this device. Use it after reinstalling if your data hasn't reappeared.")
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundColor(AppColors.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.bottom, 24)

                Button(action: onConfirm) {
                    Text("Restore Now")
                        .font(.custom("Inter-Bold", size: 15))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(AppColors.accentGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.bottom, 8)

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.custom("Inter-Medium", size: 15))
                        .foregroundColor(AppColors.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Bluetooth settings (mockup 22)

struct BluetoothSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var bluetoothService: BluetoothService

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader(title: "BLUETOOTH", leading: .back) { dismiss() }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsSectionLabel("CONNECTION STATUS")
                        SettingsRow {
                            Text("STATUS").modifier(RowLabel())
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textSubdued)
                                    .frame(width: 8, height: 8)
                                Text(bluetoothService.isConnected ? "Connected" : "Disconnected")
                                    .font(.custom("Inter-Medium", size: 13))
                                    .foregroundColor(bluetoothService.isConnected ? AppColors.accentGreen : AppColors.textSubdued)
                            }
                        }
                        if bluetoothService.isConnected {
                            SettingsRow {
                                Text("BATTERY LEVEL").modifier(RowLabel())
                                Spacer()
                                Text("\(bluetoothService.batteryLevel)%").modifier(SettingsValue())
                            }
                        }

                        SettingsSectionLabel("TROUBLESHOOTING")
                        TroubleStep(num: 1, text: "Make sure Bluetooth is enabled on your iPhone")
                        TroubleStep(num: 2, text: "Enable Bluetooth on your The Speed Machine device")
                        TroubleStep(num: 3, text: "Set The Speed Machine to Speed Mode")
                        TroubleStep(num: 4, text: "Tap \u{201C}Scan for Devices\u{201D} on the connection screen")
                        SettingsFooter("If you're having trouble, try toggling Bluetooth off and on again on both devices.")

                        SettingsSectionLabel("TECHNICAL DETAILS")
                        TechRow(label: "SERVICE UUID", value: BLEConstants.serviceUUID)
                        TechRow(label: "DEVICE NAME", value: BLEConstants.deviceName)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

private struct TroubleStep: View {
    let num: Int
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(num)")
                .font(.custom("Inter-Bold", size: 11))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(AppColors.accentGreen)
                .clipShape(Circle())
            Text(text)
                .font(.custom("Inter-Medium", size: 14))
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 10)
    }
}

private struct TechRow: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Inter-Bold", size: 11))
                .kerning(1.8)
                .foregroundColor(AppColors.textSubdued)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }
}
