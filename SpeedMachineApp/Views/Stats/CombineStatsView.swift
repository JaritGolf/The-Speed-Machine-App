//
//  CombineStatsView.swift
//  SpeedMachine
//
//  Whoop minimal Combine stats (mockup 20).
//

import SwiftUI

struct CombineStatsView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss

    @State private var games: [CombineGameData] = []
    @State private var showTrends = false
    @State private var showHistory = false

    private var highScore: Int { Int(dataService.userProgress.combineHighScore) }
    private var averageScore: Int {
        guard !games.isEmpty else { return 0 }
        return games.reduce(0) { $0 + Int($1.totalScore) } / games.count
    }
    /// Games oldest → newest for the trend line.
    private var chrono: [CombineGameData] {
        games.sorted { ($0.playedAt ?? .distantPast) < ($1.playedAt ?? .distantPast) }
    }
    private var improving: Bool {
        let v = chrono.map { Int($0.totalScore) }
        guard let f = v.first, let l = v.last else { return true }
        return l >= f
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                StatsHeader(title: "COMBINE") { dismiss() }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // KPI 3-up
                        HStack(alignment: .top, spacing: 24) {
                            KpiCell(value: "\(highScore)", unit: "", label: "HIGH SCORE")
                            KpiCell(value: "\(averageScore)", unit: "", label: "AVG SCORE")
                            KpiCell(value: "\(games.count)", unit: "", label: "GAMES")
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 22)

                        if chrono.count >= 2 {
                            scoreTrend
                        }

                        // Game history
                        HStack {
                            Text("GAME HISTORY")
                                .font(.custom("Inter-Bold", size: 15))
                                .kerning(2.0)
                                .foregroundColor(AppColors.textSubdued)
                            Spacer()
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)

                        if games.isEmpty {
                            Text("No Combine games yet. Play the Combine to see your scores here.")
                                .font(.custom("Inter-Regular", size: 14))
                                .foregroundColor(AppColors.textSubdued)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(games, id: \.id) { game in
                                CombineGameRow(game: game, isHighScore: Int(game.totalScore) == highScore)
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            StatsTabBar(active: .combine) { tab in
                switch tab {
                case .stats:   dismiss()
                case .trends:  showTrends = true
                case .history: showHistory = true
                case .combine: break
                }
            }
        }
        .fullScreenCover(isPresented: $showTrends) { TrendsView() }
        .fullScreenCover(isPresented: $showHistory) { SessionHistoryView() }
        .onAppear { games = statsService.getAllCombineGames() }
    }

    private var scoreTrend: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text("SCORE TREND")
                    .font(.custom("Inter-Bold", size: 15))
                    .kerning(2.0)
                    .foregroundColor(AppColors.textSubdued)
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(chrono.last?.totalScore ?? 0))")
                            .font(.custom("Inter-Black", size: 30))
                            .foregroundColor(.black)
                        Text("pts")
                            .font(.custom("Inter-Bold", size: 13))
                            .foregroundColor(AppColors.textSubdued)
                    }
                    Text(improving ? "↑ IMPROVING" : "↓ DECLINING")
                        .font(.custom("Inter-Bold", size: 10))
                        .kerning(1.4)
                        .foregroundColor(improving ? AppColors.accentGreen : AppColors.error)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                // Y axis: highest score (top) → lowest score (bottom).
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(Int(chrono.map { $0.totalScore }.max() ?? 0))")
                    Spacer(minLength: 0)
                    Text("\(Int(chrono.map { $0.totalScore }.min() ?? 0))")
                }
                .font(.custom("Inter-SemiBold", size: 9))
                .foregroundColor(AppColors.textSubdued)
                .frame(width: 28, height: 120, alignment: .trailing)

                VStack(spacing: 6) {
                    SimpleLineChart(values: chrono.map { Double($0.totalScore) }, color: AppColors.accentAmber)
                        .frame(height: 120)
                    // X axis: oldest game (left) → newest (right).
                    HStack {
                        Text(chrono.first?.playedAt?.toDisplayString() ?? "")
                        Spacer()
                        Text(chrono.last?.playedAt?.toDisplayString() ?? "")
                    }
                    .font(.custom("Inter-SemiBold", size: 10))
                    .foregroundColor(AppColors.textSubdued)
                }
            }

            Text("Y: GAME SCORE (pts) · X: DATE PLAYED")
                .font(.custom("Inter-SemiBold", size: 9))
                .kerning(0.5)
                .foregroundColor(AppColors.textSubdued)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }
}

// MARK: - Simple line chart (chromeless, gradient fill)

struct SimpleLineChart: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let maxV = values.max() ?? 1
            let minV = values.min() ?? 0
            let range = max(1, maxV - minV)
            let pts: [CGPoint] = values.enumerated().map { i, v in
                let x = values.count <= 1 ? 0 : w * CGFloat(Double(i) / Double(values.count - 1))
                let y = h - 6 - (h - 12) * CGFloat((v - minV) / range)
                return CGPoint(x: x, y: y)
            }
            ZStack {
                if pts.count >= 2 {
                    // gradient fill under the line
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: h))
                        pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [color.opacity(0.18), color.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    // line
                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    // end dot
                    Circle().fill(color).frame(width: 9, height: 9).position(pts.last!)
                }
            }
        }
    }
}

struct CombineGameRow: View {
    let game: CombineGameData
    let isHighScore: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(game.totalScore)")
                    .font(.custom("Inter-Black", size: 24))
                    .foregroundColor(.black)
                if let date = game.playedAt {
                    Text(date.toDisplayString().uppercased())
                        .font(.custom("Inter-Bold", size: 11))
                        .kerning(1.0)
                        .foregroundColor(AppColors.textSubdued)
                }
            }
            Spacer()
            if isHighScore {
                Text("BEST")
                    .font(.custom("Inter-Bold", size: 10))
                    .kerning(1.4)
                    .foregroundColor(AppColors.accentAmber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.accentAmber, lineWidth: 1))
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 14)
        .overlay(Rectangle().fill(AppColors.border).frame(height: 1), alignment: .top)
    }
}
