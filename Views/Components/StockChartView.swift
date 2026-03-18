//
//  StockChartView.swift
//  Boardroom Tycoon
//
//  Line chart with X (time) and Y (price) axes.
//

import SwiftUI

struct StockChartView: View {
    let points: [StockPricePoint]
    var title: String = "30D"
    var lineColor: Color = AppTheme.accent
    var showGradient: Bool = true
    var showAxes: Bool = true
    var isLoading: Bool = false

    private static let chartHeight: CGFloat = 180
    private static let yAxisWidth: CGFloat = 52
    private static let xAxisHeight: CGFloat = 22
    private static let axisLabelCount: Int = 5

    private var sortedPoints: [StockPricePoint] {
        points.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        if isLoading {
            chartLoadingView
        } else if sortedPoints.isEmpty {
            chartEmptyView
        } else if showAxes {
            chartWithAxes
        } else {
            chartWithoutAxes
        }
    }

    private var chartLoadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.9)
                .tint(lineColor)
            Text("Loading chart…")
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(height: Self.chartHeight + Self.xAxisHeight + 40)
        .frame(maxWidth: .infinity)
        .padding(AppTheme.cardPadding)
        .background(AppTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
    }

    private var chartEmptyView: some View {
        Text("No history")
            .font(AppTheme.caption())
            .foregroundStyle(AppTheme.textTertiary)
            .frame(height: Self.chartHeight + Self.xAxisHeight + 40)
            .frame(maxWidth: .infinity)
            .padding(AppTheme.cardPadding)
            .background(AppTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
    }

    private var chartWithAxes: some View {
        let pts = sortedPoints
        let minP = pts.map(\.price).min() ?? 0
        let maxP = pts.map(\.price).max() ?? 1
        let range = max(maxP - minP, 0.01)
        let minT = pts.first?.timestamp.timeIntervalSince1970 ?? 0
        let maxT = pts.last?.timestamp.timeIntervalSince1970 ?? 1
        let tRange = max(maxT - minT, 1)
        let priceLabels = Self.priceLabels(min: minP, max: maxP)
        let timeLabels = Self.timeLabels(points: pts)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                if let last = pts.last {
                    Text(String(format: "$%.2f", last.price))
                        .font(AppTheme.monoNumber())
                        .foregroundStyle(lineColor)
                }
            }

            HStack(alignment: .top, spacing: 6) {
                // Price key: position labels evenly so the lowest label hits the bottom of the chart.
                ZStack(alignment: .topLeading) {
                    let pad: CGFloat = 2
                    let interval = (Self.chartHeight - pad * 2) / CGFloat(Self.axisLabelCount - 1)
                    ForEach(0..<Self.axisLabelCount, id: \.self) { i in
                        // Top label is max, bottom label is min.
                        let idx = max(0, min(priceLabels.count - 1, priceLabels.count - 1 - i))
                        let value = priceLabels[idx]
                        Text(Self.formatPrice(value))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.textTertiary)
                            .offset(y: pad + CGFloat(i) * interval)
                    }
                }
                .frame(width: Self.yAxisWidth, height: Self.chartHeight, alignment: .topLeading)

                Rectangle()
                    .fill(AppTheme.border.opacity(0.9))
                    .frame(width: 1)

                VStack(spacing: 2) {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let pad: CGFloat = 2
                        let drawW = max(0, w - pad * 2)
                        let drawH = max(0, h - pad * 2)
                        let last = pts.last

                        ZStack(alignment: .bottomLeading) {
                            // Grid lines behind the chart line.
                            ForEach(0..<Self.axisLabelCount, id: \.self) { i in
                                let frac = CGFloat(i) / CGFloat(Self.axisLabelCount - 1) // 0=min -> bottom, 1=max -> top
                                let y = (h - pad) - frac * drawH
                                Path { p in
                                    p.move(to: CGPoint(x: 0, y: y))
                                    p.addLine(to: CGPoint(x: w, y: y))
                                }
                                .stroke(AppTheme.border.opacity(0.35), lineWidth: 1)
                            }

                            if showGradient {
                                chartFillPath(pts: pts, width: w, height: h, minP: minP, range: range, minT: minT, tRange: tRange)
                                    .fill(
                                        LinearGradient(
                                            colors: [lineColor.opacity(0.35), lineColor.opacity(0.02)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                            chartLinePath(pts: pts, width: w, height: h, minP: minP, range: range, minT: minT, tRange: tRange)
                                .stroke(lineColor, lineWidth: 2)

                            // Last-point marker.
                            if let last {
                                let t = last.timestamp.timeIntervalSince1970
                                let x = pad + CGFloat((t - minT) / tRange) * drawW
                                let y = h - pad - CGFloat((last.price - minP) / range) * drawH
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.background.opacity(0.95))
                                        .frame(width: 8, height: 8)
                                    Circle()
                                        .stroke(lineColor, lineWidth: 2)
                                        .frame(width: 10, height: 10)
                                }
                                .position(x: x, y: y)
                            }
                        }
                    }
                    .frame(height: Self.chartHeight)

                    HStack {
                        ForEach(Array(timeLabels.enumerated()), id: \.offset) { idx, item in
                            Text(item.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AppTheme.textTertiary)
                            if idx < timeLabels.count - 1 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .frame(height: Self.xAxisHeight)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.surfaceAlt)
        .shadow(color: lineColor.opacity(0.16), radius: 16, x: 0, y: 10)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: pts.count)
    }

    private var chartWithoutAxes: some View {
        let pts = sortedPoints
        let minP = pts.map(\.price).min() ?? 0
        let maxP = pts.map(\.price).max() ?? 1
        let range = max(maxP - minP, 0.01)
        let minT = pts.first?.timestamp.timeIntervalSince1970 ?? 0
        let maxT = pts.last?.timestamp.timeIntervalSince1970 ?? 1
        let tRange = max(maxT - minT, 1)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                if let last = pts.last {
                    Text(String(format: "$%.2f", last.price))
                        .font(AppTheme.monoNumber())
                        .foregroundStyle(lineColor)
                }
            }
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack(alignment: .bottomLeading) {
                    if showGradient {
                        chartFillPath(pts: pts, width: w, height: h, minP: minP, range: range, minT: minT, tRange: tRange)
                            .fill(
                                LinearGradient(
                                    colors: [lineColor.opacity(0.35), lineColor.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    chartLinePath(pts: pts, width: w, height: h, minP: minP, range: range, minT: minT, tRange: tRange)
                        .stroke(lineColor, lineWidth: 2)
                }
            }
            .frame(height: Self.chartHeight)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.surfaceAlt)
        .shadow(color: lineColor.opacity(0.16), radius: 16, x: 0, y: 10)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: pts.count)
    }

    private static func priceLabels(min: Double, max: Double) -> [Double] {
        // When prices are flat (min == max), still return axisLabelCount labels
        // so the y-axis renderer can't index out of range.
        if max <= min {
            return Array(repeating: min, count: axisLabelCount)
        }
        var labels: [Double] = []
        for i in 0..<axisLabelCount {
            let fraction = Double(i) / Double(axisLabelCount - 1)
            labels.append(min + (max - min) * fraction)
        }
        return labels
    }

    private static func formatPrice(_ value: Double) -> String {
        if value >= 1000 { return String(format: "%.1fk", value / 1000) }
        if value >= 1 { return String(format: "%.2f", value) }
        return String(format: "%.3f", value)
    }

    private static func timeLabels(points: [StockPricePoint]) -> [(offset: Int, label: String)] {
        let pts = points.sorted { $0.timestamp < $1.timestamp }
        guard !pts.isEmpty else { return [] }
        let count = min(axisLabelCount, pts.count)
        let step = max(1, (pts.count - 1) / max(1, count - 1))
        let indices = (0..<count).map { min($0 * step, pts.count - 1) }
        let calendar = Calendar.current
        let isIntraday = pts.count >= 2 && abs(pts.last!.timestamp.timeIntervalSince(pts.first!.timestamp)) < 24 * 3600
        let formatter = DateFormatter()
        formatter.dateFormat = isIntraday ? "HH:mm" : "M/d"
        return indices.map { (offset: $0, label: formatter.string(from: pts[$0].timestamp)) }
    }

    private func chartLinePath(pts: [StockPricePoint], width: CGFloat, height: CGFloat, minP: Double, range: Double, minT: TimeInterval, tRange: TimeInterval) -> Path {
        var path = Path()
        guard !pts.isEmpty, range > 0 else { return path }
        let pad: CGFloat = 2
        let drawW = width - pad * 2
        let drawH = height - pad * 2
        for (i, pt) in pts.enumerated() {
            let t = pt.timestamp.timeIntervalSince1970
            let x = pad + CGFloat((t - minT) / tRange) * drawW
            let y = height - pad - CGFloat((pt.price - minP) / range) * drawH
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }

    private func chartFillPath(pts: [StockPricePoint], width: CGFloat, height: CGFloat, minP: Double, range: Double, minT: TimeInterval, tRange: TimeInterval) -> Path {
        var path = chartLinePath(pts: pts, width: width, height: height, minP: minP, range: range, minT: minT, tRange: tRange)
        let pad: CGFloat = 2
        let drawW = width - pad * 2
        path.addLine(to: CGPoint(x: pad + drawW, y: height - pad))
        path.addLine(to: CGPoint(x: pad, y: height - pad))
        path.closeSubpath()
        return path
    }
}

#Preview {
    let points = StockService.generateFakeHistory(symbol: "GLD", currentPrice: 184.50, timeFrame: .oneDay)
    return StockChartView(points: points, title: "1D")
        .padding()
        .background(AppTheme.background)
}
