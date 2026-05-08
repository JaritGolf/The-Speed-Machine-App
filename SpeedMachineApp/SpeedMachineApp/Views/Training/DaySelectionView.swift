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
        // iPad: 5 columns in both orientations — more room for day cards
        // iPhone landscape: 6 columns (verticalSizeClass == .compact)
        // iPhone portrait: 3 columns
        let count: Int
        if isIPad {
            count = 5
        } else if verticalSizeClass == .compact {
            count = 6
        } else {
            count = 3
        }
        return Array(repeating: GridItem(.flexible()), count: count)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Phase Headers
                        ForEach(1...3, id: \.self) { phase in
                            PhaseSection(phase: phase)
                        }
                    }
                    .padding()
                    .adaptiveContentFrame()
                }
            }
            .navigationTitle("Training Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(item: $selectedTrack) { track in
                BlockSelectionView(track: track)
            }
        }
        .navigationViewStyle(.stack)
        .onChange(of: trainingViewModel.shouldNavigateHome) { _, shouldGo in
            if shouldGo {
                trainingViewModel.shouldNavigateHome = false
                selectedTrack = nil   // dismiss BlockSelectionView
                dismiss()           // dismiss TrackSelectionView back to HomeView
            }
        }
    }

    @ViewBuilder
    func PhaseSection(phase: Int) -> some View {
        let tracks = trainingViewModel.getAllTracks().filter { $0.phase == phase }
        let phaseInfo = trainingViewModel.getPhase(phase)

        if !tracks.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phase \(phase): \(phaseInfo?.name ?? "")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryBlack)

                    if let phaseInfo = phaseInfo {
                        Text(phaseInfo.focus)
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                }

                LazyVGrid(columns: columns, spacing: 12) {
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

    var status: TrackStatus {
        trainingViewModel.getTrackStatus(track.number)
    }

    var isGateTest: Bool {
        trainingViewModel.isGateTestTrack(track.number)
    }

    var body: some View {
        Button(action: {
            if status != .locked {
                action()
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: 50, height: 50)

                    if status == .completed {
                        Image(systemName: "checkmark")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } else if status == .locked {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    } else {
                        Text("\(track.number)")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                    }
                }

                Text("Track \(track.number)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryBlack)

                if isGateTest {
                    Text("Gate Test")
                        .font(.system(size: 8))
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.accentLight)
                        .cornerRadius(4)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: status == .current ? 3 : 1)
            )
        }
        .disabled(status == .locked)
    }

    var backgroundColor: Color {
        switch status {
        case .locked:
            return AppColors.textMuted
        case .available:
            return AppColors.accentGreen
        case .current:
            return AppColors.accentBright
        case .completed:
            return AppColors.accentGreen
        }
    }

    var borderColor: Color {
        switch status {
        case .current:
            return AppColors.accentBright
        default:
            return AppColors.border
        }
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
        NavigationView {
            ZStack {
                AppColors.backgroundAlt.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Day Info Header
                        VStack(alignment: .leading, spacing: 12) {
                            Text(track.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primaryBlack)

                            Text(track.objective)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textMuted)

                            HStack(spacing: 16) {
                                Label(track.duration, systemImage: "clock")
                                Label("\(track.targetPutts) putts", systemImage: "figure.golf")
                                Label(track.speedRange, systemImage: "speedometer")
                            }
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(12)

                        // Warnings if any
                        if !track.warnings.isEmpty {
                            ForEach(track.warnings, id: \.message) { warning in
                                WarningBanner(warning: warning)
                            }
                        }

                        // Science Section (Expandable)
                        if let science = track.science {
                            ExpandableSection(
                                title: "Science",
                                icon: "brain.head.profile",
                                isExpanded: $showScience
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(science.principle)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.primaryBlack)

                                    Text(science.explanation)
                                        .font(.caption)
                                        .foregroundColor(AppColors.textMuted)

                                    Text("— \(science.citation)")
                                        .font(.caption2)
                                        .italic()
                                        .foregroundColor(AppColors.textMuted)
                                }
                            }
                        }

                        // Coaching Notes (Expandable)
                        if let coachingNotes = track.coachingNotes, !coachingNotes.isEmpty {
                            ExpandableSection(
                                title: "Coaching Notes",
                                icon: "lightbulb",
                                isExpanded: $showCoaching
                            ) {
                                Text(coachingNotes)
                                    .font(.caption)
                                    .foregroundColor(AppColors.textMuted)
                            }
                        }

                        // Success Metrics
                        if !track.successMetrics.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Success Metrics")
                                    .font(.headline)
                                    .foregroundColor(AppColors.primaryBlack)

                                ForEach(track.successMetrics, id: \.metric) { metric in
                                    HStack {
                                        Image(systemName: "target")
                                            .foregroundColor(AppColors.accentGreen)
                                            .frame(width: 20)

                                        Text(metric.metric)
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.primaryBlack)

                                        Spacer()

                                        Text(metric.target)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.accentGreen)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }

                        // Training Blocks
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Training Blocks")
                                .font(.headline)
                                .foregroundColor(AppColors.primaryBlack)

                            ForEach(track.blocks) { block in
                                BlockRow(block: block, track: track)
                            }
                        }
                    }
                    .padding()
                    .adaptiveContentFrame(maxWidth: 680)
                }
            }
            .navigationTitle("Track \(track.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
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
            if !isLocked {
                trainingViewModel.startBlock(block, for: track)
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Speed indicator or block type icon
                    ZStack {
                        Circle()
                            .fill(isLocked ? AppColors.textMuted.opacity(0.15) : blockTypeColor.opacity(0.15))
                            .frame(width: 50, height: 50)

                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.title3)
                                .foregroundColor(AppColors.textMuted)
                        } else if let targetSpeed = block.targetSpeed {
                            Text("\(targetSpeed)")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundColor(blockTypeColor)
                        } else {
                            Image(systemName: blockTypeIcon)
                                .font(.title3)
                                .foregroundColor(blockTypeColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(block.name)
                            .font(.headline)
                            .foregroundColor(isLocked ? AppColors.textMuted : AppColors.primaryBlack)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(blockTypeLabel)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(isLocked ? AppColors.textMuted.opacity(0.1) : blockTypeColor.opacity(0.15))
                                .foregroundColor(isLocked ? AppColors.textMuted : blockTypeColor)
                                .cornerRadius(4)

                            Text(block.duration)
                                .font(.caption)
                                .foregroundColor(AppColors.textMuted)

                            if let putts = block.putts {
                                Text("\(putts) putts")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textMuted)
                            }
                        }
                    }

                    Spacer()

                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.accentGreen)
                    } else if isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(AppColors.textMuted)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppColors.textMuted)
                    }
                }

                // Gate test requirements
                if block.type == .gateTest, let requirements = block.passRequirements {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pass Requirement:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryBlack)

                        HStack(spacing: 16) {
                            Label({
                                let minInZone = requirements.minOverallInZone ?? requirements.zoneAccuracy?.minimum ?? 0
                                let pct = requirements.zoneAccuracy?.percentage ?? Int((Float(minInZone) / Float(block.putts ?? 1)) * 100)
                                return "\(minInZone)/\(block.putts ?? 0) in zone (\(pct)%)"
                            }(), systemImage: "circle.circle")
                            .font(.caption2)
                            .foregroundColor(AppColors.textMuted)
                        }
                    }
                    .padding(.top, 4)
                }

                // Block description
                if let description = block.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(isLocked ? AppColors.backgroundAlt : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isLocked ? AppColors.border : (block.type == .gateTest ? AppColors.bleBlue : AppColors.border),
                            lineWidth: isLocked ? 1 : (block.type == .gateTest ? 2 : 1))
            )
            .opacity(isLocked ? 0.7 : 1.0)
        }
        .disabled(isLocked)
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
