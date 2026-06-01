//
//  TrendsView.swift
//  SpeedMachine
//
//  Whoop minimal trends (mockup 15): range tabs + chromeless chart sections.
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
        case allTime = "ALL"
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
        if let days = selectedRange.days { return statsService.getDailySnapshots(days: days) }
        return statsService.getAllDailySnapshots()
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                StatsHeader(title: "TRENDS") { dismiss() }

                // Range tabs
                HStack(spacing: 0) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button { selectedRange = range } label: {
                            VStack(spacing: 8) {
                                Text(range.rawValue)
                                    .font(.custom("Inter-Bold", size: 13))
                                    .kerning(1.0)
                                    .foregroundColor(selectedRange == range ? .black : AppColors.textSubdued)
                                Rectangle()
                                    .fill(selectedRange == range ? Color.black : Color.clear)
                                    .frame(height: 2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .bottom)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if snapshots.count < 2 {
                            Text("Complete a few sessions to see your trends over time.")
                                .font(.custom("Inter-Regular", size: 14))
                                .foregroundColor(AppColors.textSubdued)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 28)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            TrendSection(
                                label: "ACCURACY",
                                value: String(format: "%.0f", snapshots.last?.accuracy ?? 0), unit: "%",
                                points: snapshots.map { $0.accuracy },
                                dates: dateRange,
                                color: AppColors.accentGreen,
                                idealUp: true
                            )
                            TrendSection(
                                label: "AVG DEVIATION",
                                value: String(format: "%.2f", snapshots.last?.averageDeviation ?? 0), unit: " MPH",
                                points: snapshots.map { $0.averageDeviation },
                                dates: dateRange,
                                color: AppColors.bleBlue,
                                idealUp: false
                            )
                            TrendSection(
                                label: "DAILY PUTTS",
                                value: "\(snapshots.last?.totalPutts ?? 0)", unit: "",
                                points: snapshots.map { Double($0.totalPutts) },
                                dates: dateRange,
                                color: AppColors.accentAmber,
                                idealUp: true
                            )
                        }
                    }
                    .padding(.bottom, 16)
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

    private var dateRange: (String, String) {
        let f = { (d: Date?) in d?.toShortDateString() ?? "" }
        return (f(snapshots.first?.date), f(snapshots.last?.date))
    }
}

// MARK: - Chromeless trend section

struct TrendSection: View {
    let label: String
    let value: String
    let unit: String
    let points: [Double]
    let dates: (String, String)
    let color: Color
    let idealUp: Bool

    private var improving: Bool {
        guard points.count >= 2 else { return true }
        let half = points.count / 2
        let firstAvg = points.prefix(half).reduce(0,+) / Double(max(1, half))
        let secondAvg = points.suffix(points.count - half).reduce(0,+) / Double(max(1, points.count - half))
        return idealUp ? secondAvg >= firstAvg : secondAvg <= firstAvg
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(label)
                    .font(.custom("Inter-Bold", size: 13))
                    .kerning(2.0)
                    .foregroundColor(AppColors.textSubdued)
                    .padding(.top, 4)
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(value)
                            .font(.custom("Inter-Black", size: 30))
                            .foregroundColor(.black)
                        Text(unit)
                            .font(.custom("Inter-Bold", size: 15))
                            .foregroundColor(AppColors.textSubdued)
                    }
                    Text((idealUp ? "↑ " : "↓ ") + (improving ? "IMPROVING" : "NEEDS FOCUS"))
                        .font(.custom("Inter-Bold", size: 10))
                        .kerning(1.4)
                        .foregroundColor(improving ? AppColors.accentGreen : AppColors.error)
                }
            }
            MiniLineChart(data: points, color: color).frame(height: 80)
            HStack {
                Text(dates.0); Spacer(); Text(dates.1)
            }
            .font(.custom("Inter-SemiBold", size: 10))
            .foregroundColor(AppColors.textSubdued)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }
}

// MARK: - Trend data model

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum IdealDirection { case up, down }

// MARK: - Mini Line Chart (custom drawn)

struct MiniLineChart: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let minVal = (data.min() ?? 0) * 0.95
            let maxVal = max((data.max() ?? 1) * 1.05, minVal + 0.1)
            let range = maxVal - minVal

            ZStack {
                // Fill gradient
                Path { path in
                    for (index, value) in data.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                        let y = height - (height * CGFloat((value - minVal) / range))
                        if index == 0 { path.move(to: CGPoint(x: x, y: height)); path.addLine(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.18), color.opacity(0)], startPoint: .top, endPoint: .bottom))

                // Line
                Path { path in
                    for (index, value) in data.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                        let y = height - (height * CGFloat((value - minVal) / range))
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if let lastValue = data.last {
                    let y = height - (height * CGFloat((lastValue - minVal) / range))
                    Circle().fill(color).frame(width: 7, height: 7).position(x: width, y: y)
                }
            }
        }
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
