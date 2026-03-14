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

                Path { path in
                    for (i, pt) in pts.enumerated() {
                        let t = pt.timestamp.timeIntervalSince1970
                        let x = padding + CGFloat((t - minT) / tRange) * drawW
                        let y = height - padding - CGFloat((pt.price - minP) / range) * drawH
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(lineColor.opacity(0.9), lineWidth: 1.5)
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
