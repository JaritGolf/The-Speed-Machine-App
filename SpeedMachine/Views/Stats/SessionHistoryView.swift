//
//  SessionHistoryView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

// MARK: - Session History List

struct SessionHistoryView: View {
    @EnvironmentObject var statsService: StatsService
    @Environment(\.dismiss) var dismiss

    @State private var sessions: [SessionData] = []
    @State private var selectedSession: SessionData?

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()

                if sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.textMuted.opacity(0.5))

                        Text("No sessions yet")
                            .font(.headline)
                            .foregroundColor(AppColors.primaryBlack)

                        Text("Your session history will appear here after you complete your first training block.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(sessions, id: \.id) { session in
                                SessionHistoryRow(session: session)
                                    .onTapGesture {
                                        selectedSession = session
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
            .onAppear {
                sessions = statsService.getAllSessions()
            }
        }
        .navigationViewStyle(.stack)
    }
}

// Make SessionData identifiable for sheet
extension SessionData: Identifiable {}

// MARK: - Session History Row

struct SessionHistoryRow: View {
    let session: SessionData

    private var accuracy: Int {
        guard session.completedPutts > 0 else { return 0 }
        return Int((Float(session.onTargetPutts) / Float(session.completedPutts)) * 100)
    }

    private var accuracyColor: Color {
        if accuracy >= 75 { return AppColors.accentGreen }
        if accuracy >= 50 { return .orange }
        return AppColors.error
    }

    var body: some View {
        HStack(spacing: 14) {
            // Accuracy ring
            ZStack {
                Circle()
                    .stroke(AppColors.backgroundAlt, lineWidth: 4)
                    .frame(width: 48, height: 48)

                Circle()
                    .trim(from: 0, to: CGFloat(accuracy) / 100)
                    .stroke(accuracyColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))

                Text("\(accuracy)%")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundColor(accuracyColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Track \(session.dayNumber)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryBlack)

                Text(session.blockId ?? "Block")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)

                if let date = session.startedAt {
                    Text(date.toDisplayString())
                        .font(.caption2)
                        .foregroundColor(AppColors.textMuted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.onTargetPutts)/\(session.completedPutts)")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundColor(AppColors.primaryBlack)

                Text("on target")
                    .font(.caption2)
                    .foregroundColor(AppColors.textMuted)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(AppColors.textMuted)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Session Detail View (putt-by-putt deep dive)

struct SessionDetailView: View {
    let session: SessionData
    @EnvironmentObject var statsService: StatsService
    @Environment(\.dismiss) var dismiss

    @State private var putts: [PuttRecordData] = []

    private var accuracy: Int {
        guard session.completedPutts > 0 else { return 0 }
        return Int((Float(session.onTargetPutts) / Float(session.completedPutts)) * 100)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Session Summary
                        SessionSummaryCard(session: session, putts: putts)

                        // Miss direction summary
                        if !putts.isEmpty {
                            MissDirectionCard(putts: putts)
                        }

                        // Putt-by-putt table
                        PuttByPuttCard(putts: putts)
                    }
                    .padding()
                }
            }
            .navigationTitle("Track \(session.dayNumber) • \(session.blockId ?? "Block")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if let sessionId = session.id {
                    putts = statsService.getPuttRecords(for: sessionId)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Session Summary Card

struct SessionSummaryCard: View {
    let session: SessionData
    let putts: [PuttRecordData]

    private var accuracy: Int {
        guard session.completedPutts > 0 else { return 0 }
        return Int((Float(session.onTargetPutts) / Float(session.completedPutts)) * 100)
    }

    private var avgDeviation: Double {
        guard !putts.isEmpty else { return 0 }
        let total = putts.reduce(0.0) { $0 + Double($1.difference) }
        return total / Double(putts.count)
    }

    var body: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                VStack(spacing: 4) {
                    Text("\(accuracy)%")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(AppColors.primaryBlack)
                    Text("Accuracy")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }

                VStack(spacing: 4) {
                    Text("\(session.completedPutts)")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(AppColors.primaryBlack)
                    Text("Putts")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }

                VStack(spacing: 4) {
                    Text(String(format: "%.2f", avgDeviation))
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(AppColors.primaryBlack)
                    Text("Avg Miss")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
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
}

// MARK: - Miss Direction Card

struct MissDirectionCard: View {
    let putts: [PuttRecordData]

    private var fastMisses: Int {
        putts.filter { !$0.isOnTarget && $0.actualSpeed > $0.targetSpeed }.count
    }

    private var slowMisses: Int {
        putts.filter { !$0.isOnTarget && $0.actualSpeed < $0.targetSpeed }.count
    }

    private var totalMisses: Int { fastMisses + slowMisses }

    var body: some View {
        guard totalMisses > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Miss Direction")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryBlack)

                HStack(spacing: 0) {
                    // Slow bar
                    if slowMisses > 0 {
                        VStack(spacing: 4) {
                            Text("\(slowMisses)")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundColor(.white)
                            Text("Slow")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(width: CGFloat(slowMisses) / CGFloat(totalMisses) * (UIScreen.main.bounds.width - 64))
                        .padding(.vertical, 12)
                        .background(AppColors.bleBlue)
                    }

                    // Fast bar
                    if fastMisses > 0 {
                        VStack(spacing: 4) {
                            Text("\(fastMisses)")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundColor(.white)
                            Text("Fast")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(width: CGFloat(fastMisses) / CGFloat(totalMisses) * (UIScreen.main.bounds.width - 64))
                        .padding(.vertical, 12)
                        .background(AppColors.error)
                    }
                }
                .cornerRadius(8)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        )
    }
}

// MARK: - Putt By Putt Card

struct PuttByPuttCard: View {
    let putts: [PuttRecordData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Putt by Putt")
                .font(.headline)
                .foregroundColor(AppColors.primaryBlack)

            if putts.isEmpty {
                Text("No putt data available")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textMuted)
                    .padding()
            } else {
                // Header row
                HStack {
                    Text("#")
                        .frame(width: 30, alignment: .leading)
                    Text("Target")
                        .frame(width: 55, alignment: .trailing)
                    Text("Actual")
                        .frame(width: 55, alignment: .trailing)
                    Text("Diff")
                        .frame(width: 55, alignment: .trailing)
                    Spacer()
                    Text("Result")
                        .frame(width: 40, alignment: .center)
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textMuted)
                .padding(.horizontal, 4)

                Divider()

                ForEach(Array(putts.enumerated()), id: \.offset) { index, putt in
                    HStack {
                        Text("\(index + 1)")
                            .frame(width: 30, alignment: .leading)
                            .foregroundColor(AppColors.textMuted)

                        Text(String(format: "%.0f", putt.targetSpeed))
                            .frame(width: 55, alignment: .trailing)
                            .foregroundColor(AppColors.primaryBlack)

                        Text(String(format: "%.1f", putt.actualSpeed))
                            .frame(width: 55, alignment: .trailing)
                            .foregroundColor(AppColors.primaryBlack)

                        let signed = putt.actualSpeed - putt.targetSpeed
                        Text(String(format: "%+.1f", signed))
                            .frame(width: 55, alignment: .trailing)
                            .foregroundColor(putt.isOnTarget ? AppColors.accentGreen : AppColors.error)

                        Spacer()

                        Image(systemName: putt.isOnTarget ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(putt.isOnTarget ? AppColors.accentGreen : AppColors.error)
                            .frame(width: 40, alignment: .center)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)

                    if index < putts.count - 1 {
                        Divider()
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
}
