//
//  TrendsView.swift
//  SpeedMachine
//
//  Created by Claude for Jarit Golf
//

import SwiftUI

struct TrendsView: View {
    @EnvironmentObject var statsService: StatsService
    @Environment(\.dismiss) var dismiss

    @State private var selectedRange: TimeRange = .thirtyDays
    @State private var showStats = false
    @State private var showHistory = false
    @State private var showCombine = false

    enum TimeRange: String, CaseIterable {
        case sevenDays = "7D"
        case thirtyDays = "30D"
        case ninetyDays = "90D"
        case allTime = "All"

        var days: Int? {
            switch self {
            case .sevenDays: return 7
            case .thirtyDays: return 30
            case .ninetyDays: return 90
            case .allTime: return nil
            }
        }
    }

    private var snapshots: [DailySnapshotData] {
        if let days = selectedRange.days {
            return statsService.getDailySnapshots(days: days)
        } else {
            return statsService.getAllDailySnapshots()
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    Spacer()
                    Text("TRENDS")
                        .font(.custom("Inter-Bold", size: 13))
                        .kerning(2.5)
                        .foregroundColor(.black)
                    Spacer()
                    Color.clear.frame(width: 28, height: 28)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 12)

                Divider().overlay(AppColors.border)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Picker("Range", selection: $selectedRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)

                        if snapshots.isEmpty {
                            EmptyTrendsCard()
                        } else {
                            // Accuracy Trend
                            TrendChartCard(
                                title: "Accuracy",
                                subtitle: "Percentage of putts on target",
                                data: snapshots.map { TrendPoint(date: $0.date ?? Date(), value: $0.accuracy) },
                                valueFormat: "%.0f%%",
                                color: AppColors.accentGreen,
                                idealDirection: .up
                            )

                            // Consistency Trend (avg deviation — lower is better)
                            TrendChartCard(
                                title: "Average Deviation",
                                subtitle: "How far off target (lower is better)",
                                data: snapshots.map { TrendPoint(date: $0.date ?? Date(), value: $0.averageDeviation) },
                                valueFormat: "%.2f MPH",
                                color: AppColors.bleBlue,
                                idealDirection: .down
                            )

                            // Practice Volume
                            TrendChartCard(
                                title: "Daily Putts",
                                subtitle: "Practice volume per day",
                                data: snapshots.map { TrendPoint(date: $0.date ?? Date(), value: Double($0.totalPutts)) },
                                valueFormat: "%.0f",
                                color: .orange,
                                idealDirection: .up
                            )

                            // Practice Time
                            if snapshots.contains(where: { $0.practiceMinutes > 0 }) {
                                TrendChartCard(
                                    title: "Practice Time",
                                    subtitle: "Minutes per day",
                                    data: snapshots.map { TrendPoint(date: $0.date ?? Date(), value: $0.practiceMinutes) },
                                    valueFormat: "%.0f min",
                                    color: .purple,
                                    idealDirection: .up
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            StatsTabBar(active: .trends) { tab in
                switch tab {
                case .stats:   dismiss()
                case .history: showHistory = true
                case .combine: showCombine = true
                case .trends:  break
                }
            }
        }
        .fullScreenCover(isPresented: $showHistory) { SessionHistoryView() }
        .fullScreenCover(isPresented: $showCombine) { CombineStatsView() }
    }
}

// MARK: - Trend Data Model

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum IdealDirection {
    case up, down
}

// MARK: - Trend Chart Card (custom drawn, no Charts framework dependency)

struct TrendChartCard: View {
    let title: String
    let subtitle: String
    let data: [TrendPoint]
    let valueFormat: String
    let color: Color
    let idealDirection: IdealDirection

    private var latestValue: String {
        guard let last = data.last else { return "—" }
        return String(format: valueFormat, last.value)
    }

    private var trendDirection: String {
        guard data.count >= 2 else { return "" }
        let firstHalf = data.prefix(data.count / 2)
        let secondHalf = data.suffix(data.count / 2)
        let firstAvg = firstHalf.map(\.value).reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map(\.value).reduce(0, +) / Double(secondHalf.count)

        let improving: Bool
        switch idealDirection {
        case .up: improving = secondAvg > firstAvg
        case .down: improving = secondAvg < firstAvg
        }

        return improving ? "Improving" : "Needs focus"
    }

    private var trendColor: Color {
        return trendDirection == "Improving" ? AppColors.accentGreen : .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(AppColors.primaryBlack)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(latestValue)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(AppColors.primaryBlack)

                    if data.count >= 4 {
                        Text(trendDirection)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(trendColor)
                    }
                }
            }

            // Mini chart
            if data.count >= 2 {
                MiniLineChart(data: data.map(\.value), color: color)
                    .frame(height: 80)
            }

            // Date range label
            if let first = data.first?.date, let last = data.last?.date {
                HStack {
                    Text(first.toShortDateString())
                    Spacer()
                    Text(last.toShortDateString())
                }
                .font(.caption2)
                .foregroundColor(AppColors.textMuted)
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

// MARK: - Mini Line Chart (custom drawn)

struct MiniLineChart: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let minVal = (data.min() ?? 0) * 0.9
            let maxVal = max((data.max() ?? 1) * 1.1, minVal + 0.1)
            let range = maxVal - minVal

            // Line path
            Path { path in
                for (index, value) in data.enumerated() {
                    let x = width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                    let y = height - (height * CGFloat((value - minVal) / range))

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            // Fill gradient
            Path { path in
                for (index, value) in data.enumerated() {
                    let x = width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                    let y = height - (height * CGFloat((value - minVal) / range))

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: height))
                        path.addLine(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.2), color.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Latest value dot
            if let lastValue = data.last {
                let x = width
                let y = height - (height * CGFloat((lastValue - minVal) / range))
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .position(x: x, y: y)
            }
        }
    }
}

// MARK: - Empty State

struct EmptyTrendsCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textMuted.opacity(0.5))

            Text("No trend data yet")
                .font(.headline)
                .foregroundColor(AppColors.primaryBlack)

            Text("Complete a few sessions to see your trends over time.")
                .font(.subheadline)
                .foregroundColor(AppColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Date Extension

extension Date {
    func toShortDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
}
