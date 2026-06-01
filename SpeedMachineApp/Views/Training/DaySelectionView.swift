//
//  DaySelectionView.swift
//  SpeedMachine
//
//  Track grid (mockup 04) + block selection (mockup 05), Whoop minimal style.
//

import SwiftUI

struct DaySelectionView: View {
    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedDay: TrainingDay?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    private var allDays: [TrainingDay] { trainingViewModel.getAllDays() }
    private var completedCount: Int { allDays.filter { trainingViewModel.isDayCompleted($0.day) }.count }
    private var currentTrack: TrainingDay? { trainingViewModel.getDay(trainingViewModel.currentDay) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header: ← TRAINING PROGRAM
                HStack(spacing: 16) {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(.black)
                    }
                    Text("TRAINING PROGRAM")
                        .font(.custom("Inter-Bold", size: 13))
                        .kerning(2.5)
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .padding(.bottom, 4)

                if allDays.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    // Progress block
                    progressBlock
                        .padding(.horizontal, 32)
                        .padding(.top, 14)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            let phases = Array(Set(allDays.map { $0.phase })).sorted()
                            ForEach(phases, id: \.self) { phase in
                                phaseSection(phase: phase)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 22)
                        .padding(.bottom, 16)
                    }

                    if let track = currentTrack {
                        Button { selectedDay = track } label: {
                            Text("Resume Track \(String(format: "%02d", track.day)) →")
                                .font(.custom("Inter-Bold", size: 16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(AppColors.accentGreen)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 10)
                        .padding(.bottom, 26)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedDay) { day in
            BlockSelectionView(day: day)
        }
        .onAppear {
            trainingViewModel.repairMissingCompletions()
        }
        .onChange(of: trainingViewModel.shouldNavigateHome) { _, shouldGo in
            if shouldGo {
                trainingViewModel.shouldNavigateHome = false
                selectedDay = nil
                dismiss()
            }
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(String(format: "%02d", completedCount))
                    .font(.custom("Inter-Black", size: 64))
                    .foregroundColor(.black)
                Text("of \(allDays.count) complete")
                    .font(.custom("Inter-Bold", size: 16))
                    .foregroundColor(AppColors.textSubdued)
            }
            if let track = currentTrack {
                Text("CURRENT · TRACK \(String(format: "%02d", track.day)) — \(track.title.uppercased())")
                    .font(.custom("Inter-Bold", size: 11))
                    .kerning(2.0)
                    .foregroundColor(AppColors.textSubdued)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ProgressBarThin(fraction: allDays.isEmpty ? 0 : Double(completedCount) / Double(allDays.count))
                .padding(.top, 6)
        }
    }

    @ViewBuilder
    private func phaseSection(phase: Int) -> some View {
        let days = allDays.filter { $0.phase == phase }
        let phaseInfo = trainingViewModel.getPhase(phase)
        if !days.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PHASE \(String(format: "%02d", phase))")
                        .font(.custom("Inter-Bold", size: 10))
                        .kerning(2.2)
                        .foregroundColor(AppColors.textSubdued)
                    if let phaseInfo = phaseInfo {
                        Text(phaseInfo.name)
                            .font(.custom("Inter-Black", size: 20))
                            .foregroundColor(.black)
                        Text(phaseInfo.focus)
                            .font(.custom("Inter-SemiBold", size: 11))
                            .foregroundColor(AppColors.textMuted)
                    }
                }
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(days) { day in
                        TrackCard(day: day) { selectedDay = day }
                    }
                }
            }
        }
    }
}

// MARK: - Thin progress bar

struct ProgressBarThin: View {
    let fraction: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.border)
                Capsule().fill(AppColors.accentGreen)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Track tile (mockup .tc)

struct TrackCard: View {
    let day: TrainingDay
    let action: () -> Void

    @EnvironmentObject var trainingViewModel: TrainingViewModel

    var status: DayStatus { trainingViewModel.getDayStatus(day.day) }
    var isGateTest: Bool { trainingViewModel.isGateTestDay(day.day) }

    var body: some View {
        Button(action: { if status != .locked { action() } }) {
            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "%02d", day.day))
                    .font(.custom("Inter-Black", size: 22))
                    .foregroundColor(numberColor)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(day.title.uppercased())
                    .font(.custom("Inter-Bold", size: 8))
                    .kerning(0.4)
                    .foregroundColor(labelColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .aspectRatio(1, contentMode: .fit)
            .padding(9)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .overlay(alignment: .topTrailing) { cornerStatus }
        }
        .disabled(status == .locked)
    }

    @ViewBuilder
    private var cornerStatus: some View {
        if isGateTest {
            Text("GATE")
                .font(.custom("Inter-Black", size: 6.5))
                .kerning(0.8)
                .foregroundColor(status == .completed ? .white.opacity(0.9) : AppColors.textSubdued)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background((status == .completed ? Color.white.opacity(0.18) : Color.black.opacity(0.06)))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(6)
        } else if status == .completed {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppColors.accentGreen)
                .padding(7)
        } else if status == .current {
            Circle()
                .fill(AppColors.accentGreen)
                .frame(width: 7, height: 7)
                .shadow(color: AppColors.accentGreen.opacity(0.6), radius: 3)
                .padding(8)
        }
    }

    private var cardBg: Color {
        switch status {
        case .completed: return .black
        case .locked:    return AppColors.surfaceAlt
        case .current:   return .white
        case .available: return .white
        }
    }
    private var numberColor: Color {
        switch status {
        case .completed: return .white
        case .locked:    return Color(hex: "d4d4d4")
        case .current:   return .black
        case .available: return .black
        }
    }
    private var labelColor: Color {
        switch status {
        case .completed: return .white.opacity(0.6)
        case .locked:    return Color(hex: "d4d4d4")
        case .current:   return AppColors.textMuted
        case .available: return AppColors.textMuted
        }
    }
    private var borderColor: Color {
        status == .current ? .black : Color.clear
    }
    private var borderWidth: CGFloat { status == .current ? 2 : 0 }
}

// MARK: - Block selection (mockup 05)

struct BlockSelectionView: View {
    let day: TrainingDay

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss

    private var completedBlocks: Int {
        day.blocks.filter { dataService.isBlockCompleted(dayNumber: day.day, blockId: $0.blockId) }.count
    }
    private var nextBlockIndex: Int? {
        day.blocks.firstIndex { !dataService.isBlockCompleted(dayNumber: day.day, blockId: $0.blockId) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header: ← TRACK NN
                HStack(spacing: 16) {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(.black)
                    }
                    Text("TRACK \(String(format: "%02d", day.day))")
                        .font(.custom("Inter-Bold", size: 13))
                        .kerning(2.5)
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .padding(.bottom, 4)

                // Progress block
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(String(format: "%02d", completedBlocks))
                            .font(.custom("Inter-Black", size: 64))
                            .foregroundColor(.black)
                        Text("of \(day.blocks.count) complete")
                            .font(.custom("Inter-Bold", size: 16))
                            .foregroundColor(AppColors.textSubdued)
                    }
                    Text("\(day.title.uppercased()) · \(day.targetPutts) PUTTS · \(day.duration.uppercased())")
                        .font(.custom("Inter-Bold", size: 11))
                        .kerning(2.0)
                        .foregroundColor(AppColors.textSubdued)
                        .fixedSize(horizontal: false, vertical: true)
                    ProgressBarThin(fraction: day.blocks.isEmpty ? 0 : Double(completedBlocks) / Double(day.blocks.count))
                        .padding(.top, 6)
                }
                .padding(.horizontal, 32)
                .padding(.top, 14)
                .padding(.bottom, 14)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(day.blocks.enumerated()), id: \.element.id) { idx, block in
                            BlockRow(block: block, day: day, index: idx)
                        }
                    }
                }

                if let next = nextBlockIndex {
                    Button {
                        trainingViewModel.startBlock(day.blocks[next], for: day)
                    } label: {
                        Text("Start Block \(next + 1) →")
                            .font(.custom("Inter-Bold", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppColors.accentGreen)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
                    .padding(.bottom, 26)
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

// MARK: - Block row (mockup .block-row)

struct BlockRow: View {
    let block: TrainingBlock
    let day: TrainingDay
    let index: Int

    @EnvironmentObject var trainingViewModel: TrainingViewModel
    @EnvironmentObject var dataService: DataService

    var isCompleted: Bool {
        dataService.isBlockCompleted(dayNumber: day.day, blockId: block.blockId)
    }
    var isLocked: Bool {
        guard let i = day.blocks.firstIndex(where: { $0.blockId == block.blockId }) else { return false }
        for j in 0..<i where !dataService.isBlockCompleted(dayNumber: day.day, blockId: day.blocks[j].blockId) {
            return true
        }
        return false
    }
    var isCurrent: Bool { !isCompleted && !isLocked }

    var body: some View {
        Button {
            if !isLocked { trainingViewModel.startBlock(block, for: day) }
        } label: {
            HStack(alignment: .top, spacing: 16) {
                Text(String(format: "%02d", index + 1))
                    .font(.custom("Inter-Bold", size: 13))
                    .foregroundColor(numColor)
                    .frame(width: 18, alignment: .leading)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 5) {
                    Text(block.name)
                        .font(.custom("Inter-Bold", size: 17))
                        .foregroundColor(nameColor)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(blockTypeLabel.uppercased())
                            .font(.custom("Inter-Bold", size: 10))
                            .kerning(1.6)
                            .foregroundColor(typeColor)
                        Text("·").foregroundColor(metaColor)
                        Text(metaString)
                            .font(.custom("Inter-SemiBold", size: 10))
                            .foregroundColor(metaColor)
                    }
                }

                Spacer(minLength: 8)

                statusView
                    .padding(.top, 2)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isCompleted ? Color.black : Color.white)
            .opacity(isLocked ? 0.42 : 1)
            .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
        }
        .disabled(isLocked)
    }

    @ViewBuilder
    private var statusView: some View {
        if isCompleted {
            Text("✓")
                .font(.custom("Inter-Black", size: 15))
                .foregroundColor(AppColors.accentGreen)
        } else if isLocked {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSubdued)
        } else {
            Circle()
                .fill(AppColors.accentGreen)
                .frame(width: 8, height: 8)
                .shadow(color: AppColors.accentGreen.opacity(0.5), radius: 3)
        }
    }

    private var metaString: String {
        var parts: [String] = []
        if let p = block.putts { parts.append("\(p) putts") }
        if !block.duration.isEmpty { parts.append(block.duration) }
        parts.append(blockSpeedRange)
        return parts.joined(separator: " · ")
    }

    private var blockSpeedRange: String {
        if let seq = block.sequence, let lo = seq.min(), let hi = seq.max() {
            return lo == hi ? "\(lo) MPH" : "\(lo)–\(hi) MPH"
        }
        if let s = block.startSpeed, let e = block.endSpeed {
            return "\(Swift.min(s, e))–\(Swift.max(s, e)) MPH"
        }
        if let t = block.targetSpeed { return "\(t) MPH" }
        return day.speedRange
    }

    private var blockTypeLabel: String {
        switch block.type {
        case .exploration:  return "Exploration"
        case .blocked:      return "Standard"
        case .alternating:  return "Alternating"
        case .sequence:     return "Sequence"
        case .warmup:       return "Warm-Up"
        case .predictive:   return "Predictive"
        case .gateTest:     return "Gate Test"
        case .random:       return "Random"
        case .pressure:     return "Pressure"
        case .recovery:     return "Recovery"
        case .challenge:    return "Challenge"
        case .assessment:   return "Assessment"
        case .reactive:     return "Reactive"
        case .combine:      return "Combine"
        case .celebration:  return "Celebration"
        }
    }

    // Colors
    private var nameColor: Color { isCompleted ? .white : .black }
    private var numColor: Color { isCompleted ? Color(hex: "808080") : AppColors.textSubdued }
    private var metaColor: Color { isCompleted ? Color(hex: "808080") : AppColors.textSubdued }
    private var typeColor: Color {
        if isCompleted { return Color(hex: "808080") }
        switch block.type {
        case .gateTest: return AppColors.bleBlue
        case .pressure: return AppColors.error
        default:        return AppColors.textMuted
        }
    }
}
