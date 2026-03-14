//
//  StockService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

/// Chart timeframe for price history.
enum ChartTimeFrame: String, CaseIterable, Identifiable {
    case oneMin = "1m"
    case fiveMin = "5m"
    case fifteenMin = "15m"
    case oneHour = "1H"
    case oneDay = "1D"
    case all = "All"

    var id: String { rawValue }

    var displayName: String { rawValue }
}

final class StockService {
    private let db = Firestore.firestore()

    /// Demo stocks when Firestore has none (for testing / first run).
    static let fakeStocks: [Stock] = [
        Stock(id: "gld", name: "Gold", symbol: "GLD", currentPrice: 184.50, priceChange: 2.34),
        Stock(id: "dmd", name: "Diamond", symbol: "DMD", currentPrice: 412.00, priceChange: -8.20),
        Stock(id: "oil", name: "Oil", symbol: "OIL", currentPrice: 72.80, priceChange: 1.15),
        Stock(id: "slv", name: "Silver", symbol: "SLV", currentPrice: 24.90, priceChange: 0.45),
        Stock(id: "cl", name: "Coal", symbol: "CL", currentPrice: 56.20, priceChange: -1.80),
        Stock(id: "irn", name: "Iron", symbol: "IRN", currentPrice: 98.40, priceChange: 3.10)
    ]

    func fetchStocks(completion: @escaping (Result<[Stock], Error>) -> Void) {
        let stocksRef = db.collection("stockSymbols")

        stocksRef.getDocuments { [weak self] snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let stocks: [Stock] = documents.compactMap { document in
                let data = document.data()
                guard
                    let id = data["id"] as? String,
                    let name = data["name"] as? String,
                    let symbol = data["symbol"] as? String,
                    let currentPrice = data["currentPrice"] as? Double,
                    let priceChange = data["priceChange"] as? Double
                else { return nil }
                return Stock(
                    id: id,
                    name: name,
                    symbol: symbol,
                    currentPrice: currentPrice,
                    priceChange: priceChange
                )
            }

            // Use fake stocks for testing when Firestore has none
            let result = stocks.isEmpty ? Self.fakeStocks : stocks
            completion(.success(result))
        }
    }

    /// Returns fake price history for a stock for the given timeframe.
    func fetchPriceHistory(for stock: Stock, timeFrame: ChartTimeFrame, completion: @escaping ([StockPricePoint]) -> Void) {
        let points = Self.generateFakeHistory(symbol: stock.symbol, currentPrice: stock.currentPrice, timeFrame: timeFrame)
        completion(points)
    }

    /// Generates fake price history for a timeframe (for testing).
    static func generateFakeHistory(symbol: String, currentPrice: Double, timeFrame: ChartTimeFrame) -> [StockPricePoint] {
        let (count, intervalSeconds) = timeFrame.pointCountAndInterval()
        var points: [StockPricePoint] = []
        var price = currentPrice
        var date = Date()

        for i in 0..<count {
            let id = "\(symbol)-\(timeFrame.rawValue)-\(i)"
            points.append(StockPricePoint(id: id, timestamp: date, price: price))
            date = date.addingTimeInterval(-intervalSeconds)
            let change = Double.random(in: -0.015...0.015)
            price = max(0.01, price / (1 + change))
        }

        return points.sorted { $0.timestamp < $1.timestamp }
    }

    /// Generates fake history with a fixed point count (e.g. sparklines). Uses daily spacing for count ≤ 31.
    static func generateFakeHistory(symbol: String, currentPrice: Double, count: Int = 31) -> [StockPricePoint] {
        let interval: TimeInterval = count <= 31 ? 24 * 3600 : 24 * 3600
        var points: [StockPricePoint] = []
        var price = currentPrice
        var date = Date()
        for i in 0..<count {
            points.append(StockPricePoint(id: "\(symbol)-\(i)", timestamp: date, price: price))
            date = date.addingTimeInterval(-interval)
            let change = Double.random(in: -0.02...0.02)
            price = max(0.01, price / (1 + change))
        }
        return points.sorted { $0.timestamp < $1.timestamp }
    }
}

extension ChartTimeFrame {
    /// (number of points, seconds between points)
    fileprivate func pointCountAndInterval() -> (Int, TimeInterval) {
        switch self {
        case .oneMin: return (60, 1)
        case .fiveMin: return (60, 5)
        case .fifteenMin: return (60, 15)
        case .oneHour: return (60, 60)
        case .oneDay: return (24, 3600)
        case .all: return (31, 24 * 3600)
        }
    }
}
