//
//  StockChartView.swift
//  Boardroom Tycoon
//
//  Line chart for stock price history (fake data for testing).
//

import SwiftUI

struct StockChartView: View {
    let points: [StockPricePoint]
    var title: String = "30D"
    var lineColor: Color = AppTheme.accent
    var showGradient: Bool = true
    var isLoading: Bool = false

    private var sortedPoints: [StockPricePoint] {
        points.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        if isLoading {
            VStack(spacing: 10) {
                ProgressView()
                    .scaleEffect(0.9)
                    .tint(lineColor)
                Text("Loading chart…")
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .padding(AppTheme.cardPadding)
            .background(AppTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        } else if sortedPoints.isEmpty {
            Text("No history")
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textTertiary)
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .padding(AppTheme.cardPadding)
                .background(AppTheme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    if let last = sortedPoints.last {
                        Text(String(format: "$%.2f", last.price))
                            .font(AppTheme.monoNumber())
                            .foregroundStyle(lineColor)
                    }
                }

                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    let pts = sortedPoints
                    let minP = pts.map(\.price).min() ?? 0
                    let maxP = pts.map(\.price).max() ?? 1
                    let range = max(maxP - minP, 0.01)
                    let minT = pts.first?.timestamp.timeIntervalSince1970 ?? 0
                    let maxT = pts.last?.timestamp.timeIntervalSince1970 ?? 1
                    let tRange = max(maxT - minT, 1)

                    ZStack(alignment: .bottomLeading) {
                        if showGradient {
                            chartFillPath(pts: pts, width: width, height: height, minP: minP, range: range, minT: minT, tRange: tRange)
                                .fill(
                                    LinearGradient(
                                        colors: [lineColor.opacity(0.35), lineColor.opacity(0.02)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        chartLinePath(pts: pts, width: width, height: height, minP: minP, range: range, minT: minT, tRange: tRange)
                            .stroke(lineColor, lineWidth: 2)
                    }
                }
                .frame(height: 120)
            }
            .padding(AppTheme.cardPadding)
            .background(AppTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        }
    }

    private func chartLinePath(pts: [StockPricePoint], width: CGFloat, height: CGFloat, minP: Double, range: Double, minT: TimeInterval, tRange: TimeInterval) -> Path {
        var path = Path()
        guard !pts.isEmpty, range > 0 else { return path }
        let padding: CGFloat = 2
        let drawWidth = width - padding * 2
        for (i, pt) in pts.enumerated() {
            let t = pt.timestamp.timeIntervalSince1970
            let x = padding + CGFloat((t - minT) / tRange) * drawWidth
            let y = height - padding - CGFloat((pt.price - minP) / range) * (height - padding * 2)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }

    private func chartFillPath(pts: [StockPricePoint], width: CGFloat, height: CGFloat, minP: Double, range: Double, minT: TimeInterval, tRange: TimeInterval) -> Path {
        var path = chartLinePath(pts: pts, width: width, height: height, minP: minP, range: range, minT: minT, tRange: tRange)
        let padding: CGFloat = 2
        let drawWidth = width - padding * 2
        path.addLine(to: CGPoint(x: padding + drawWidth, y: height - padding))
        path.addLine(to: CGPoint(x: padding, y: height - padding))
        path.closeSubpath()
        return path
    }
}

#Preview {
    let points = StockService.generateFakeHistory(symbol: "GLD", currentPrice: 184.50, count: 31)
    return StockChartView(points: points, title: "30D")
        .padding()
        .background(AppTheme.background)
}
