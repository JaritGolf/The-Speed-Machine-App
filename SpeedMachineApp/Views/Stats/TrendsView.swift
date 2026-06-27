//
//  TrendsView.swift
//  SpeedMachine
//
//  Rethought Trends: per-putt rolling-average accuracy (fixed 0–100 scale),
//  a per-zone breakdown that surfaces the weakest zone, and a practice-
//  consistency grid. Built from PuttRecordData (training + practice). Combine
//  shots have no per-shot timestamp, so they're excluded from the rolling lines
//  but still count in the practice grid (which reads DailySnapshotData).
//

import SwiftUI

struct TrendsView: View {
    @EnvironmentObject var statsService: StatsService
    @Environment(\.dismiss) var dismiss

    @State private var selectedRange: TimeRange = .thirtyDays
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
        /// Lower bound for fetching putts (nil = all time).
        var since: Date? {
            guard let days = days else { return nil }
            return Calendar.current.date(byAdding: .day, value: -(days - 1),
                                         to: Calendar.current.startOfDay(for: Date()))
        }
        var agoLabel: String {
            switch self {
            case .sevenDays:  return "7d ago"
            case .thirtyDays: return "30d ago"
            case .ninetyDays: return "90d ago"
            case .allTime:    return "start"
            }
        }
    }

    private var snapshotsForRange: [DailySnapshotData] {
        if let days = selectedRange.days { return statsService.getDailySnapshots(days: days) }
        return statsService.getAllDailySnapshots()
    }

    var body: some View {
        let model = TrendsModel(
            putts: statsService.getPuttRecords(since: selectedRange.since),
            snapshots: snapshotsForRange,
            rangeStart: selectedRange.since,
            streak: statsService.currentPracticeStreak
        )

        return ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                StatsHeader(title: "TRENDS") { dismiss() }
                rangeTabs

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if !model.hasEnoughData {
                            Text("Complete a few more sessions to see your trends over time.")
                                .font(.custom("Inter-Regular", size: 14))
                                .foregroundColor(AppColors.textSubdued)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 28)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            AccuracyTrendSection(model: model, agoLabel: selectedRange.agoLabel)
                            ZoneBreakdownSection(zones: model.zones)
                        }
                        PracticeConsistencySection(model: model)
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

    private var rangeTabs: some View {
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
    }
}

// MARK: - Trend data model

/// One rolling-average sample: an accuracy % anchored at a real timestamp.
struct TrendDatum {
    let date: Date
    let value: Double   // 0–100
}

struct ZoneTrend: Identifiable {
    let id: Int          // zone number (1–4)
    let name: String
    let rangeLabel: String
    let render: [TrendDatum]   // strided for the sparkline
    let current: Double
    let puttCount: Int
    let improving: Bool?       // nil when too few points to judge
    var hasData: Bool { puttCount >= TrendsMath.zoneMinPutts && render.count >= 2 }
}

struct DayActivity: Identifiable {
    let id: Date
    let putts: Int
}

/// Pure transform of raw putts/snapshots into everything the screen renders.
struct TrendsModel {
    let totalPutts: Int
    let overallRender: [TrendDatum]   // strided for the chart
    let overallCurrent: Double
    let overallBaseline: Double
    let zones: [ZoneTrend]
    let activity: [DayActivity]
    let activityPutts: Int
    let daysPracticed: Int
    let streak: Int

    var hasEnoughData: Bool { totalPutts >= TrendsMath.minPuttsForTrend && overallRender.count >= 2 }
    var overallDelta: Double { overallCurrent - overallBaseline }

    init(putts: [PuttRecordData], snapshots: [DailySnapshotData], rangeStart: Date?, streak: Int) {
        totalPutts = putts.count
        self.streak = streak

        // Overall rolling accuracy
        let overallWindow = TrendsMath.window(forCount: putts.count, divisor: 8, min: 15, max: 40)
        let overallFull = TrendsMath.rollingAccuracy(putts, window: overallWindow)
        overallCurrent  = overallFull.last?.value ?? 0
        overallBaseline = overallFull.first?.value ?? 0
        overallRender   = TrendsMath.stride(overallFull, to: 60)

        // Per-zone breakdown — 4 training zones only
        let trainingZones = SpeedZone.zones.filter { (1...4).contains($0.number) }
        var built: [ZoneTrend] = trainingZones.map { zone in
            let zonePutts = putts.filter { SpeedZone.getZone(for: Int(($0.targetSpeed).rounded())).number == zone.number }
            let w = TrendsMath.window(forCount: zonePutts.count, divisor: 6, min: 10, max: 30)
            let full = TrendsMath.rollingAccuracy(zonePutts, window: w)
            return ZoneTrend(
                id: zone.number,
                name: zone.name.uppercased(),
                rangeLabel: "\(zone.speedRange.lowerBound)–\(zone.speedRange.upperBound) MPH",
                render: TrendsMath.stride(full, to: 40),
                current: full.last?.value ?? 0,
                puttCount: zonePutts.count,
                improving: TrendsMath.improving(full)
            )
        }
        // Surface the weakest zone first; zones without data sink to the bottom.
        built.sort { a, b in
            if a.hasData != b.hasData { return a.hasData }
            return a.current < b.current
        }
        zones = built

        // Practice-consistency activity grid (snapshot-based, so it includes Combine)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Dedupe by calendar day with `max`. NSPersistentCloudKitContainer enforces no
        // row uniqueness, so iCloud sync can leave several DailySnapshotData rows for the
        // same day; summing them would massively inflate the count. In normal single-device
        // use there is exactly one row per day, so `max` returns the true value.
        var byDay: [Date: Int] = [:]
        for s in snapshots {
            guard let d = s.date else { continue }
            let day = cal.startOfDay(for: d)
            byDay[day] = Swift.max(byDay[day] ?? 0, Int(s.totalPutts))
        }
        let earliest = byDay.keys.min() ?? today
        let defaultStart = cal.date(byAdding: .day, value: -(TrendsMath.maxActivityDays - 1), to: today)!
        var start = rangeStart.map { cal.startOfDay(for: $0) } ?? max(earliest, defaultStart)
        // Cap the grid length so ALL-time doesn't explode.
        if let capped = cal.date(byAdding: .day, value: -(TrendsMath.maxActivityDays - 1), to: today), start < capped {
            start = capped
        }
        var days: [DayActivity] = []
        var cursor = start
        while cursor <= today {
            days.append(DayActivity(id: cursor, putts: byDay[cursor] ?? 0))
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        activity = days
        activityPutts = days.reduce(0) { $0 + $1.putts }
        daysPracticed = days.filter { $0.putts > 0 }.count
    }
}

// MARK: - Rolling-average math

enum TrendsMath {
    static let minPuttsForTrend = 20
    static let zoneMinPutts = 10
    static let maxActivityDays = 112   // 16 weeks

    /// Adaptive trailing-window size in putts.
    static func window(forCount n: Int, divisor: Int, min lo: Int, max hi: Int) -> Int {
        return Swift.max(lo, Swift.min(hi, n / divisor))
    }

    /// Trailing-window rolling accuracy. Each point = % of hits over the last
    /// `window` putts, dated at that putt's timestamp. O(n) sliding sum.
    static func rollingAccuracy(_ putts: [PuttRecordData], window: Int) -> [TrendDatum] {
        guard window > 0, putts.count >= window else { return [] }
        var out: [TrendDatum] = []
        out.reserveCapacity(putts.count - window + 1)
        var hits = 0
        for i in 0..<window where putts[i].isOnTarget { hits += 1 }
        out.append(TrendDatum(date: putts[window - 1].timestamp ?? Date(),
                              value: Double(hits) / Double(window) * 100))
        for i in window..<putts.count {
            if putts[i].isOnTarget { hits += 1 }
            if putts[i - window].isOnTarget { hits -= 1 }
            out.append(TrendDatum(date: putts[i].timestamp ?? Date(),
                                  value: Double(hits) / Double(window) * 100))
        }
        return out
    }

    /// Evenly sample a series down to at most `maxPoints` for rendering,
    /// always keeping the first and last point. Math is unchanged — purely cosmetic.
    static func stride(_ data: [TrendDatum], to maxPoints: Int) -> [TrendDatum] {
        guard data.count > maxPoints, maxPoints > 1 else { return data }
        let step = Double(data.count - 1) / Double(maxPoints - 1)
        var result: [TrendDatum] = []
        result.reserveCapacity(maxPoints)
        for k in 0..<maxPoints {
            result.append(data[Int((Double(k) * step).rounded())])
        }
        if let last = data.last, result.last?.date != last.date { result[result.count - 1] = last }
        return result
    }

    /// Second-half average vs first-half average. nil when too few points.
    static func improving(_ s: [TrendDatum]) -> Bool? {
        guard s.count >= 2 else { return nil }
        let half = s.count / 2
        let firstAvg = s.prefix(half).map { $0.value }.reduce(0, +) / Double(Swift.max(half, 1))
        let secondAvg = s.suffix(s.count - half).map { $0.value }.reduce(0, +) / Double(Swift.max(s.count - half, 1))
        return secondAvg >= firstAvg
    }
}

// MARK: - Section 1: Accuracy over time

struct AccuracyTrendSection: View {
    let model: TrendsModel
    let agoLabel: String

    private var up: Bool { model.overallDelta >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text("ACCURACY")
                    .font(.custom("Inter-Bold", size: 13))
                    .kerning(2.0)
                    .foregroundColor(AppColors.textSubdued)
                    .padding(.top, 6)
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.0f", model.overallCurrent))
                            .font(.custom("Inter-Black", size: 34))
                            .foregroundColor(.black)
                        Text("%")
                            .font(.custom("Inter-Bold", size: 16))
                            .foregroundColor(AppColors.textSubdued)
                    }
                    Text("\(up ? "▲" : "▼") \(String(format: "%.0f", abs(model.overallDelta)))% vs \(agoLabel)")
                        .font(.custom("Inter-Bold", size: 10))
                        .kerning(1.2)
                        .foregroundColor(up ? AppColors.accentGreen : AppColors.error)
                }
            }

            LabeledAccuracyChart(data: model.overallRender, color: AppColors.accentGreen, chartHeight: 110)

            Text("Y: % OF PUTTS IN TARGET ZONE (LAST \(TrendsMath.window(forCount: model.totalPutts, divisor: 8, min: 15, max: 40)) PUTTS ROLLING) · X: DATE")
                .font(.custom("Inter-SemiBold", size: 9))
                .kerning(0.5)
                .foregroundColor(AppColors.textSubdued)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }
}

// MARK: - Section 2: By-zone breakdown

struct ZoneBreakdownSection: View {
    let zones: [ZoneTrend]

    private var focusZone: ZoneTrend? {
        zones.first { $0.hasData && $0.current < 70 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("BY ZONE")
                    .font(.custom("Inter-Bold", size: 13))
                    .kerning(2.0)
                    .foregroundColor(AppColors.textSubdued)
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, focusZone == nil ? 8 : 12)

            if let focus = focusZone {
                HStack(spacing: 8) {
                    Text("FOCUS")
                        .font(.custom("Inter-Black", size: 10))
                        .kerning(1.4)
                        .foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(AppColors.error)
                        .cornerRadius(3)
                    Text("\(focus.name) is your weakest zone — drill it next.")
                        .font(.custom("Inter-SemiBold", size: 12))
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 10)
            }

            ForEach(zones) { zone in
                ZoneTrendRow(zone: zone)
            }
        }
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }
}

struct ZoneTrendRow: View {
    let zone: ZoneTrend

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(zone.name)
                    .font(.custom("Inter-Black", size: 16))
                    .foregroundColor(.black)
                Text(zone.rangeLabel)
                    .font(.custom("Inter-SemiBold", size: 11))
                    .foregroundColor(AppColors.textSubdued)
            }
            .frame(width: 96, alignment: .leading)

            if zone.hasData {
                AccuracyChart(data: zone.render, color: statAccuracyColor(zone.current), showGrid: false)
                    .frame(height: 34)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Int(zone.current))%")
                        .font(.custom("Inter-Black", size: 18))
                        .foregroundColor(statAccuracyColor(zone.current))
                    if let improving = zone.improving {
                        Text(improving ? "↑" : "↓")
                            .font(.custom("Inter-Bold", size: 12))
                            .foregroundColor(improving ? AppColors.accentGreen : AppColors.error)
                    }
                }
                .frame(width: 48, alignment: .trailing)
            } else {
                Text("Not enough data")
                    .font(.custom("Inter-SemiBold", size: 12))
                    .foregroundColor(AppColors.textSubdued)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }
}

// MARK: - Section 3: Practice consistency

struct PracticeConsistencySection: View {
    let model: TrendsModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 14)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text("CONSISTENCY")
                    .font(.custom("Inter-Bold", size: 13))
                    .kerning(2.0)
                    .foregroundColor(AppColors.textSubdued)
                    .padding(.top, 6)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(model.streak)")
                        .font(.custom("Inter-Black", size: 34))
                        .foregroundColor(.black)
                    Text("DAY STREAK")
                        .font(.custom("Inter-Bold", size: 11))
                        .kerning(1.0)
                        .foregroundColor(AppColors.textSubdued)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(model.activity) { day in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(activityColor(day.putts))
                        .aspectRatio(1, contentMode: .fit)
                }
            }

            Text("\(model.daysPracticed) days practiced · \(model.activityPutts) putts")
                .font(.custom("Inter-SemiBold", size: 11))
                .foregroundColor(AppColors.textSubdued)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }

    private func activityColor(_ putts: Int) -> Color {
        if putts == 0 { return AppColors.border }
        if putts < 20 { return AppColors.accentGreen.opacity(0.30) }
        if putts < 50 { return AppColors.accentGreen.opacity(0.60) }
        return AppColors.accentGreen
    }
}

// MARK: - Fixed-scale line chart (custom drawn)

struct AccuracyChart: View {
    let data: [TrendDatum]
    let color: Color
    var yRange: ClosedRange<Double> = 0...100
    var showGrid: Bool = true

    /// Precompute screen points outside the ViewBuilder closure.
    private func points(in size: CGSize) -> [CGPoint] {
        guard let first = data.first, let last = data.last else { return [] }
        let span = last.date.timeIntervalSince(first.date)
        let useTime = span > 60   // collapse to even spacing if all points share a moment
        let yLo = yRange.lowerBound
        let yHi = max(yRange.upperBound, yLo + 0.001)
        return data.indices.map { i in
            let d = data[i]
            let xFrac: CGFloat = useTime
                ? CGFloat(d.date.timeIntervalSince(first.date) / span)
                : CGFloat(i) / CGFloat(max(data.count - 1, 1))
            let yFrac = (d.value - yLo) / (yHi - yLo)
            return CGPoint(x: size.width * xFrac,
                           y: size.height - size.height * CGFloat(min(max(yFrac, 0), 1)))
        }
    }

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            let h = geo.size.height
            let w = geo.size.width

            ZStack {
                if showGrid {
                    ForEach([0.0, 0.5, 1.0], id: \.self) { frac in
                        Path { p in
                            let y = h - h * CGFloat(frac)
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(AppColors.border, lineWidth: 1)
                    }
                }

                if !pts.isEmpty {
                    // Fill
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: h))
                        for pt in pts { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [color.opacity(0.18), color.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))

                    // Line
                    Path { p in
                        for (i, pt) in pts.enumerated() {
                            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    Circle().fill(color).frame(width: 7, height: 7).position(pts[pts.count - 1])
                }
            }
        }
    }
}

// MARK: - Labeled chart (axis-annotated wrapper for full-size charts)

/// `AccuracyChart` with a Y-axis (% ticks aligned to the 3 gridlines) and an
/// X-axis (oldest date on the left → newest on the right). Used for the large
/// trend charts so the reader can tell what the line is measuring and over what
/// span. The tiny per-zone sparklines stay bare — their row label + current %
/// already say what they are.
struct LabeledAccuracyChart: View {
    let data: [TrendDatum]
    let color: Color
    var yRange: ClosedRange<Double> = 0...100
    var chartHeight: CGFloat = 110

    private var yTicks: [Int] {
        let hi = yRange.upperBound, lo = yRange.lowerBound
        return [Int(hi), Int((hi + lo) / 2), Int(lo)]
    }
    private var startLabel: String { data.first?.date.toShortDateString() ?? "" }
    private var endLabel: String { data.last?.date.toShortDateString() ?? "" }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Y axis: high (top) → low (bottom), aligned to AccuracyChart's gridlines.
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(yTicks.enumerated()), id: \.offset) { idx, v in
                    Text("\(v)%")
                        .font(.custom("Inter-SemiBold", size: 9))
                        .foregroundColor(AppColors.textSubdued)
                    if idx < yTicks.count - 1 { Spacer(minLength: 0) }
                }
            }
            .frame(width: 28, height: chartHeight, alignment: .trailing)

            VStack(spacing: 6) {
                AccuracyChart(data: data, color: color, yRange: yRange, showGrid: true)
                    .frame(height: chartHeight)
                // X axis: oldest (left) → newest (right).
                HStack {
                    Text(startLabel)
                    Spacer()
                    Text(endLabel)
                }
                .font(.custom("Inter-SemiBold", size: 9))
                .foregroundColor(AppColors.textSubdued)
            }
        }
    }
}

// MARK: - Helpers

extension Date {
    func toShortDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
}
