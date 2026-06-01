//
//  SessionHistoryView.swift
//  SpeedMachine
//
//  Whoop minimal session history (mockup 17) + detail (17B).
//

import SwiftUI

// MARK: - Session History List

struct SessionHistoryView: View {
    @EnvironmentObject var statsService: StatsService
    @Environment(\.dismiss) var dismiss

    @State private var sessions: [SessionData] = []
    @State private var selectedSession: SessionData?
    @State private var showTrends = false
    @State private var showCombine = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                StatsHeader(title: "HISTORY") { dismiss() }

                if sessions.isEmpty {
                    Text("Your session history will appear here after you complete your first training block.")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(AppColors.textSubdued)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(sessions, id: \.id) { session in
                                SessionHistoryRow(session: session)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedSession = session }
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            StatsTabBar(active: .history) { tab in
                switch tab {
                case .stats:   dismiss()
                case .trends:  showTrends = true
                case .combine: showCombine = true
                case .history: break
                }
            }
        }
        .sheet(item: $selectedSession) { session in SessionDetailView(session: session) }
        .fullScreenCover(isPresented: $showTrends) { TrendsView() }
        .fullScreenCover(isPresented: $showCombine) { CombineStatsView() }
        .onAppear { sessions = statsService.getAllSessions() }
    }
}

extension SessionData: Identifiable {}

struct SessionHistoryRow: View {
    let session: SessionData

    private var accuracy: Int {
        guard session.completedPutts > 0 else { return 0 }
        return Int((Float(session.onTargetPutts) / Float(session.completedPutts)) * 100)
    }
    private var color: Color { statAccuracyColor(Double(accuracy)) }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                if let date = session.startedAt {
                    Text(date.toShortDateString().uppercased())
                        .font(.custom("Inter-Bold", size: 10))
                        .kerning(1.2)
                        .foregroundColor(AppColors.textSubdued)
                }
                Text("Track \(session.dayNumber)")
                    .font(.custom("Inter-Bold", size: 16))
                    .foregroundColor(.black)
                Text("\(session.completedPutts) putts")
                    .font(.custom("Inter-SemiBold", size: 11))
                    .foregroundColor(AppColors.textSubdued)
            }
            Spacer()
            Text("\(accuracy)%")
                .font(.custom("Inter-Black", size: 22))
                .foregroundColor(color)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppColors.textSubdued)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }
}

// MARK: - Session Detail (17B)

struct SessionDetailView: View {
    let session: SessionData
    @EnvironmentObject var statsService: StatsService
    @Environment(\.dismiss) var dismiss

    @State private var putts: [PuttRecordData] = []

    private var accuracy: Int {
        guard session.completedPutts > 0 else { return 0 }
        return Int((Float(session.onTargetPutts) / Float(session.completedPutts)) * 100)
    }
    private var avgMiss: Double {
        guard !putts.isEmpty else { return 0 }
        return putts.reduce(0.0) { $0 + Double($1.actualSpeed - $1.targetSpeed) } / Double(putts.count)
    }
    private var avgMissColor: Color {
        if avgMiss > 0.05 { return AppColors.accentAmber }
        if avgMiss < -0.05 { return AppColors.bleBlue }
        return AppColors.accentGreen
    }
    private var slowMisses: Int { putts.filter { !$0.isOnTarget && $0.actualSpeed < $0.targetSpeed }.count }
    private var fastMisses: Int { putts.filter { !$0.isOnTarget && $0.actualSpeed > $0.targetSpeed }.count }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                StatsHeader(title: "TRACK \(session.dayNumber)") { dismiss() }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // KPI 3-up
                        HStack(alignment: .top, spacing: 24) {
                            KpiCell(value: "\(accuracy)", unit: "%", label: "ACCURACY")
                            KpiCell(value: "\(session.completedPutts)", unit: "", label: "PUTTS")
                            KpiCellColored(value: String(format: "%+.2f", avgMiss), label: "AVG MISS", valueColor: avgMissColor)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 22)

                        if slowMisses + fastMisses > 0 {
                            missDirection
                        }
                        if !putts.isEmpty {
                            puttStrip
                            puttTable
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            if let id = session.id { putts = statsService.getPuttRecords(for: id) }
        }
    }

    private var missDirection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MISS DIRECTION")
                .font(.custom("Inter-Bold", size: 11))
                .kerning(2.2)
                .foregroundColor(AppColors.textSubdued)
            GeometryReader { geo in
                let total = max(1, slowMisses + fastMisses)
                let gap: CGFloat = (slowMisses > 0 && fastMisses > 0) ? 2 : 0
                let avail = geo.size.width - gap
                HStack(spacing: gap) {
                    if slowMisses > 0 {
                        Text("SLOW · \(slowMisses)")
                            .font(.custom("Inter-Bold", size: 11)).foregroundColor(.white)
                            .frame(width: avail * CGFloat(slowMisses) / CGFloat(total), height: 34)
                            .background(AppColors.bleBlue)
                    }
                    if fastMisses > 0 {
                        Text("FAST · \(fastMisses)")
                            .font(.custom("Inter-Bold", size: 11)).foregroundColor(.white)
                            .frame(width: avail * CGFloat(fastMisses) / CGFloat(total), height: 34)
                            .background(AppColors.error)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .frame(height: 34)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }

    private var puttStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PUTT STRIP")
                .font(.custom("Inter-Bold", size: 11))
                .kerning(2.2)
                .foregroundColor(AppColors.textSubdued)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(putts.enumerated()), id: \.offset) { _, p in
                    let dev = abs(Double(p.actualSpeed - p.targetSpeed))
                    let h: CGFloat = dev > 0.5 ? 20 : (dev > 0.25 ? 13 : 8)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(p.isOnTarget ? AppColors.accentGreen : AppColors.error)
                        .frame(width: 8, height: h)
                }
            }
            .frame(height: 22, alignment: .bottom)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }

    private var puttTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PUTT BY PUTT")
                .font(.custom("Inter-Bold", size: 11))
                .kerning(2.2)
                .foregroundColor(AppColors.textSubdued)
                .padding(.bottom, 12)

            HStack {
                Text("#").frame(width: 24, alignment: .leading)
                Text("TARGET").frame(maxWidth: .infinity, alignment: .leading)
                Text("ACTUAL").frame(maxWidth: .infinity, alignment: .leading)
                Text("DIFF").frame(maxWidth: .infinity, alignment: .leading)
                Text("").frame(width: 20)
            }
            .font(.custom("Inter-Bold", size: 10))
            .kerning(1.0)
            .foregroundColor(AppColors.textSubdued)
            .padding(.bottom, 8)
            .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .bottom)

            ForEach(Array(putts.enumerated()), id: \.offset) { i, p in
                let signed = p.actualSpeed - p.targetSpeed
                HStack {
                    Text("\(i + 1)").frame(width: 24, alignment: .leading)
                        .foregroundColor(AppColors.textSubdued)
                    Text(String(format: "%.0f", p.targetSpeed)).frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(AppColors.textMuted)
                    Text(String(format: "%.1f", p.actualSpeed)).frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.black)
                    Text(String(format: "%+.1f", signed)).frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(p.isOnTarget ? AppColors.accentGreen : AppColors.error)
                    Text(p.isOnTarget ? "✓" : "✗").frame(width: 20, alignment: .trailing)
                        .foregroundColor(p.isOnTarget ? AppColors.accentGreen : AppColors.error)
                }
                .font(.custom("Inter-SemiBold", size: 13))
                .padding(.vertical, 7)
                .overlay(Rectangle().fill(AppColors.border.opacity(0.5)).frame(height: 1), alignment: .bottom)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }
}

// KPI cell with a colored value (for AVG MISS)
struct KpiCellColored: View {
    let value: String
    let label: String
    let valueColor: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.custom("Inter-Black", size: 28))
                .foregroundColor(valueColor)
            Text(label)
                .font(.custom("Inter-Bold", size: 10))
                .kerning(2.0)
                .foregroundColor(AppColors.textSubdued)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
