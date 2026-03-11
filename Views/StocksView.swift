//
//  StocksView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct StocksView: View {
    let stocks: [Stock] = [
        Stock(
            id: "stock-gold",
            name: "Gold Sector",
            symbol: "GLD",
            currentPrice: 124.50,
            priceChange: 2.35
        ),
        Stock(
            id: "stock-oil",
            name: "Oil Sector",
            symbol: "OIL",
            currentPrice: 88.20,
            priceChange: -1.40
        ),
        Stock(
            id: "stock-steel",
            name: "Steel Sector",
            symbol: "STL",
            currentPrice: 56.75,
            priceChange: 0.85
        ),
        Stock(
            id: "stock-construction",
            name: "Construction Sector",
            symbol: "CST",
            currentPrice: 73.10,
            priceChange: -0.55
        )
    ]

    let samplePriceHistory: [StockPricePoint] = [
        StockPricePoint(id: "point-1", timestamp: Date().addingTimeInterval(-14400), price: 120.25),
        StockPricePoint(id: "point-2", timestamp: Date().addingTimeInterval(-10800), price: 121.80),
        StockPricePoint(id: "point-3", timestamp: Date().addingTimeInterval(-7200), price: 122.40),
        StockPricePoint(id: "point-4", timestamp: Date().addingTimeInterval(-3600), price: 123.10),
        StockPricePoint(id: "point-5", timestamp: Date(), price: 124.50)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracked Price Points: \(samplePriceHistory.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            List(stocks) { stock in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stock.name)
                                .font(.headline)

                            Text(stock.symbol)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\(stock.currentPrice, specifier: "%.2f")")
                                .font(.headline)

                            Text(formattedChange(stock.priceChange))
                                .font(.caption)
                                .foregroundStyle(stock.priceChange >= 0 ? .green : .red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func formattedChange(_ change: Double) -> String {
        let absoluteChange = abs(change)
        let sign = change >= 0 ? "+" : "-"
        return "\(sign)$\(String(format: "%.2f", absoluteChange))"
    }
}

#Preview {
    NavigationStack {
        StocksView()
    }
}
