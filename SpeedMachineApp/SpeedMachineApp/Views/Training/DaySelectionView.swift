//
//  TrackSelectionView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

struct TrackSelectionView: View {
    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @State private var selectedTrack: TrainingTrack?

    var columns: [GridItem] {
        let count: Int
        if isIPad {
            count = 5
        } else if verticalSizeClass == .compact {
            count = 6
        } else {
            count = 5
        }
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Whoop-style top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    Spacer()
                    Text("TRACKS")
                        .font(.custom("Inter-Bold", size: 13))
                        .kerning(2.5)
                        .foregroundColor(.black)
                    Spacer()
                    // Balance the X button
                    Color.clear.frame(width: 28, height: 28)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 12)

                Divider().overlay(AppColors.border)

                let allTracks = trainingViewModel.getAllTracks()
                if allTracks.isEmpty {
                    Spacer()
                    ProgressView()
                    Text("Loading program…")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(AppColors.textMuted)
                        .padding(.top, 8)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            let phases = Array(Set(allTracks.map { $0.phase })).sorted()
                            ForEach(phases, id: \.self) { phase in
                                PhaseSection(phase: phase)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .adaptiveContentFrame()
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedTrack) { track in
            BlockSelectionView(track: track)
        }
        .onChange(of: trainingViewModel.shouldNavigateHome) { _, shouldGo in
            if shouldGo {
                trainingViewModel.shouldNavigateHome = false
                selectedTrack = nil
                dismiss()
            }
        }
    }

    @ViewBuilder
    func PhaseSection(phase: Int) -> some View {
        let tracks = trainingViewModel.getAllTracks().filter { $0.phase == phase }
        let phaseInfo = trainingViewModel.getPhase(phase)

        if !tracks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PHASE \(phase)")
                        .font(.custom("Inter-Bold", size: 10))
                        .kerning(2.5)
                        .foregroundColor(AppColors.textSubdued)
                    if let phaseInfo = phaseInfo {
                        Text(phaseInfo.name)
                            .font(.custom("Inter-Bold", size: 15))
                            .foregroundColor(.black)
                        Text(phaseInfo.focus)
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(AppColors.textMuted)
                    }
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(tracks) { track in
                        TrackCard(track: track) {
                            selectedTrack = track
                        }
                    }
                }
            }
        }
    }
}

struct TrackCard: View {
    let track: TrainingTrack
    let action: () -> Void

    @EnvironmentObject var trainingViewModel: TrainingViewModel

    var status: TrackStatus { trainingViewModel.getTrackStatus(track.number) }
    var isGateTest: Bool { trainingViewModel.isGateTestTrack(track.number) }

    var body: some View {
        Button(action: { if status != .locked { action() } }) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    // Status indicator
                    if status == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    } else if status == .locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSubdued)
                    } else if status == .current {
                        Circle()
                            .fill(AppColors.accentGreen)
                            .frame(width: 8, height: 8)
                    } else {
                        Spacer().frame(height: 8)
                    }

                    Text("\(track.number)")
                        .font(.custom("Inter-Black", size: 18))
                        .foregroundColor(numberColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(cardBg)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor, lineWidth: borderWidth)
                )

                // GATE badge
                if isGateTest {
                    Text("GATE")
                        .font(.custom("Inter-Bold", size: 7))
                        .kerning(0.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(AppColors.bleBlue)
                        .cornerRadius(3)
                        .offset(x: -4, y: 4)
                }
            }
        }
        .disabled(status == .locked)
    }

    private var cardBg: Color {
        switch status {
        case .completed: return .black
        case .locked:    return AppColors.surfaceAlt
        default:         return .white
        }
    }

    private var numberColor: Color {
        switch status {
        case .completed: return .white
        case .locked:    return AppColors.textSubdued
        case .current:   return .black
        case .available: return AppColors.textMuted
        }
    }

    private var borderColor: Color {
        switch status {
        case .current:  return AppColors.accentGreen
        case .locked:   return AppColors.border
        default:        return AppColors.border
        }
    }

    private var borderWidth: CGFloat {
        status == .current ? 2 : 1
    }
}

struct BlockSelectionView: View {
    let track: TrainingTrack

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    @Environment(\.dismiss) var dismiss

    @State private var showScience = false
    @State private var showCoaching = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Whoop-style top bar
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("TRACKS")
                                .font(.custom("Inter-Bold", size: 12))
                                .kerning(1.5)
                        }
                        .foregroundColor(.black)
                    }
                    Spacer()
                    Text("TRACK \(track.number)")
                        .font(.custom("Inter-Bold", size: 13))
                        .kerning(2.5)
                        .foregroundColor(.black)
                    Spacer()
                    Color.clear.frame(width: 60, height: 24)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 12)

                Divider().overlay(AppColors.border)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Track title + objective
                        VStack(alignment: .leading, spacing: 8) {
                            Text(track.title)
                                .font(.custom("Inter-Black", size: 22))
                                .foregroundColor(.black)

                            Text(track.objective)
                                .font(.custom("Inter-Regular", size: 13))
                                .foregroundColor(AppColors.textMuted)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 16) {
                                Label(track.duration, systemImage: "clock")
                                Label("\(track.targetPutts) putts", systemImage: "figure.golf")
                                Label(track.speedRange, systemImage: "speedometer")
                            }
                            .font(.custom("Inter-Regular", size: 11))
                            .foregroundColor(AppColors.textSubdued)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 20)

                        Divider().overlay(AppColors.border)

                        // Warnings
                        if !track.warnings.isEmpty {
                            ForEach(track.warnings, id: \.message) { warning in
                                WarningBanner(warning: warning)
                                    .padding(.horizontal, 22)
                                    .padding(.top, 12)
                            }
                        }

                        // Training Blocks
                        VStack(alignment: .leading, spacing: 0) {
                            Text("BLOCKS")
                                .font(.custom("Inter-Bold", size: 10))
                                .kerning(2.5)
                                .foregroundColor(AppColors.textSubdued)
                                .padding(.horizontal, 22)
                                .padding(.top, 20)
                                .padding(.bottom, 10)

                            VStack(spacing: 8) {
                                ForEach(track.blocks) { block in
                                    BlockRow(block: block, track: track)
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.bottom, 24)
                        }

                        // Science Section (Expandable)
                        if let science = track.science {
                            Divider().overlay(AppColors.border)
                            ExpandableSection(
                                title: "Science",
                                icon: "brain.head.profile",
                                isExpanded: $showScience
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(science.principle)
                                        .font(.custom("Inter-SemiBold", size: 13))
                                        .foregroundColor(.black)
                                    Text(science.explanation)
                                        .font(.custom("Inter-Regular", size: 12))
                                        .foregroundColor(AppColors.textMuted)
                                    Text("— \(science.citation)")
                                        .font(.custom("Inter-Regular", size: 11))
                                        .italic()
                                        .foregroundColor(AppColors.textSubdued)
                                }
                            }
                        }

                        // Coaching Notes
                        if let coachingNotes = track.coachingNotes, !coachingNotes.isEmpty {
                            Divider().overlay(AppColors.border)
                            ExpandableSection(
                                title: "Coaching Notes",
                                icon: "lightbulb",
                                isExpanded: $showCoaching
                            ) {
                                Text(coachingNotes)
                                    .font(.custom("Inter-Regular", size: 12))
                                    .foregroundColor(AppColors.textMuted)
                            }
                        }
                    }
                    .adaptiveContentFrame(maxWidth: 680)
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { trainingViewModel.isSessionActive },
            set: { if !$0 { trainingViewModel.endSession() } }
        )) {
            TrainingSessionView()
                .environmentObject(trainingViewModel)
                .environmentObject(bluetoothService)
        }
    }
}

struct ExpandableSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(AppColors.accentGreen)
                        .frame(width: 24)

                    Text(title)
                        .font(.headline)
                        .foregroundColor(AppColors.primaryBlack)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppColors.textMuted)
                }
                .padding()
            }

            if isExpanded {
                content()
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct WarningBanner: View {
    let warning: Warning

    var backgroundColor: Color {
        switch warning.type {
        case "critical", "extreme":
            return Color.red.opacity(0.1)
        case "caution":
            return Color.orange.opacity(0.1)
        default:
            return Color.yellow.opacity(0.1)
        }
    }

    var iconColor: Color {
        switch warning.type {
        case "critical", "extreme":
            return .red
        case "caution":
            return .orange
        default:
            return .yellow
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(iconColor)

            Text(warning.message)
                .font(.caption)
                .foregroundColor(AppColors.primaryBlack)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .cornerRadius(12)
    }
}

struct BlockRow: View {
    let block: TrainingBlock
    let track: TrainingTrack

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var dataService: DataService

    var isCompleted: Bool {
        dataService.isBlockCompleted(trackNumber: track.number, blockId: block.blockId)
    }

    var isLocked: Bool {
        guard let blockIndex = track.blocks.firstIndex(where: { $0.blockId == block.blockId }) else {
            return false
        }
        // First block is always unlocked
        if blockIndex == 0 { return false }
        // Check that all previous blocks are completed
        for i in 0..<blockIndex {
            if !dataService.isBlockCompleted(trackNumber: track.number, blockId: track.blocks[i].blockId) {
                return true
            }
        }
        return false
    }

    var blockTypeLabel: String {
        switch block.type {
        case .exploration: return "Exploration"
        case .blocked: return "Blocked"
        case .alternating: return "Alternating"
        case .sequence: return "Sequence"
        case .warmup: return "Warm-Up"
        case .predictive: return "Predictive"
        case .gateTest: return "Gate Test"
        case .random: return "Random"
        case .pressure: return "Pressure"
        case .recovery: return "Recovery"
        case .challenge: return "Challenge"
        case .assessment: return "Assessment"
        case .reactive: return "Reactive"
        case .combine: return "Combine"
        case .celebration: return "Celebration"
        }
    }

    var blockTypeColor: Color {
        switch block.type {
        case .gateTest: return AppColors.bleBlue
        case .pressure: return AppColors.error
        case .challenge: return .orange
        case .assessment: return .purple
        default: return AppColors.accentGreen
        }
    }

    var body: some View {
        Button {
            if !isLocked { trainingViewModel.startBlock(block, for: track) }
        } label: {
            HStack(spacing: 14) {
                // Left: status dot or lock
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(AppColors.accentGreen)
                        .clipShape(Circle())
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSubdued)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(blockTypeColor)
                        .frame(width: 8, height: 8)
                        .frame(width: 28, height: 28)
                }

                // Center: name + type badge
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.name)
                        .font(.custom("Inter-Bold", size: 15))
                        .foregroundColor(rowFg)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(blockTypeLabel.uppercased())
                            .font(.custom("Inter-Bold", size: 9))
                            .kerning(0.8)
                            .foregroundColor(isCompleted ? .white.opacity(0.60) : (isLocked ? AppColors.textSubdued : blockTypeColor))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(isCompleted ? Color.white.opacity(0.10) : (isLocked ? AppColors.surfaceAlt : blockTypeColor.opacity(0.12)))
                            .cornerRadius(3)

                        if let putts = block.putts {
                            Text("\(putts) PUTTS")
                                .font(.custom("Inter-Bold", size: 10))
                                .kerning(0.5)
                                .foregroundColor(isCompleted ? .white.opacity(0.45) : AppColors.textSubdued)
                        }
                    }
                }

                Spacer()

                // Right indicator
                if isCompleted {
                    // checkmark already on left, nothing on right
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSubdued)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSubdued)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(rowBg)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(rowBorder, lineWidth: rowBorderWidth)
            )
        }
        .disabled(isLocked)
    }

    private var rowBg: Color {
        if isCompleted { return .black }
        if isLocked { return AppColors.surfaceAlt }
        return .white
    }

    private var rowFg: Color {
        if isCompleted { return .white }
        if isLocked { return AppColors.textSubdued }
        return .black
    }

    private var rowBorder: Color {
        if isCompleted { return .black }
        if isLocked { return AppColors.border }
        if block.type == .gateTest { return AppColors.bleBlue }
        return AppColors.border
    }

    private var rowBorderWidth: CGFloat {
        block.type == .gateTest && !isLocked ? 1.5 : 1
    }

    var blockTypeIcon: String {
        switch block.type {
        case .exploration: return "magnifyingglass"
        case .blocked: return "square.grid.2x2"
        case .alternating: return "arrow.left.arrow.right"
        case .sequence: return "list.number"
        case .warmup: return "flame"
        case .predictive: return "brain"
        case .gateTest: return "flag.checkered"
        case .random: return "shuffle"
        case .pressure: return "bolt.fill"
        case .recovery: return "heart"
        case .challenge: return "star.fill"
        case .assessment: return "chart.bar"
        case .reactive: return "bolt"
        case .combine: return "trophy"
        case .celebration: return "party.popper"
        }
    }
}
