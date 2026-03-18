//
//  SparklineView.swift
//  Boardroom Tycoon
//
//  Mini trend line for stock list rows.
//

import SwiftUI

struct SparklineView: View {
    let points: [StockPricePoint]
    var lineColor: Color = AppTheme.accent
    var height: CGFloat = 28

    private var sortedPoints: [StockPricePoint] {
        points.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let pts = sortedPoints
            if pts.count < 2 {
                EmptyView()
            } else {
                let minP = pts.map(\.price).min() ?? 0
                let maxP = pts.map(\.price).max() ?? 1
                let range = max(maxP - minP, 0.01)
                let minT = pts.first?.timestamp.timeIntervalSince1970 ?? 0
                let maxT = pts.last?.timestamp.timeIntervalSince1970 ?? 1
                let tRange = max(maxT - minT, 1)
                let padding: CGFloat = 1
                let drawW = width - padding * 2
                let drawH = height - padding * 2
                let baselineY = height - padding
                let last = pts.last!
                let tLast = last.timestamp.timeIntervalSince1970
                let xLast = padding + CGFloat((tLast - minT) / tRange) * drawW
                let yLast = height - padding - CGFloat((last.price - minP) / range) * drawH
                let prev = pts[pts.count - 2]
                let tPrev = prev.timestamp.timeIntervalSince1970
                let xPrev = padding + CGFloat((tPrev - minT) / tRange) * drawW
                let yPrev = height - padding - CGFloat((prev.price - minP) / range) * drawH

                let linePath = Path { path in
                    for (i, pt) in pts.enumerated() {
                        let t = pt.timestamp.timeIntervalSince1970
                        let x = padding + CGFloat((t - minT) / tRange) * drawW
                        let y = height - padding - CGFloat((pt.price - minP) / range) * drawH
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }

                let fillPath = Path { path in
                    path.addPath(linePath)
                    path.addLine(to: CGPoint(x: xLast, y: baselineY))
                    path.addLine(to: CGPoint(x: padding, y: baselineY))
                    path.closeSubpath()
                }

                ZStack(alignment: .topLeading) {
                    fillPath
                        .fill(
                            LinearGradient(
                                colors: [lineColor.opacity(0.25), lineColor.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    linePath
                        .stroke(lineColor.opacity(0.95), lineWidth: 1.6)
                        .shadow(color: lineColor.opacity(0.35), radius: 4, x: 0, y: 0)

                    // Emphasize the most recent move so direction matches priceChange.
                    Path { p in
                        p.move(to: CGPoint(x: xPrev, y: yPrev))
                        p.addLine(to: CGPoint(x: xLast, y: yLast))
                    }
                    .stroke(lineColor, lineWidth: 2.6)
                    .shadow(color: lineColor.opacity(0.45), radius: 6, x: 0, y: 0)

                    // Last point marker for direction.
                    Circle()
                        .fill(AppTheme.background.opacity(0.98))
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle()
                                .stroke(lineColor, lineWidth: 2)
                        )
                        .position(x: xLast, y: yLast)
                }
                .animation(.easeInOut(duration: 0.25), value: pts.count)
            }
        }
        .frame(height: height)
    }
}

#Preview {
    let points = StockService.generateFakeHistory(symbol: "GLD", currentPrice: 184.50, count: 7)
    return SparklineView(points: points)
        .frame(width: 80, height: 28)
        .padding()
        .background(AppTheme.surface)
}
