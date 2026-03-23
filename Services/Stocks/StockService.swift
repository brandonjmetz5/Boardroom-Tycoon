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
    case oneHour = "1H"
    case oneDay = "1D"
    case oneWeek = "1W"
    case allTime = "All"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneHour: return "1H"
        case .oneDay: return "1D"
        case .oneWeek: return "1W"
        case .allTime: return "All Time"
        default: return rawValue
        }
    }
}

final class StockService {
    private let db = Firestore.firestore()
    private var stocksListener: ListenerRegistration?

    /// Demo stocks when Firestore has none (for testing / first run).
    static let fakeStocks: [Stock] = [
        Stock(id: "gld", name: "Gold", symbol: "GLD", currentPrice: 184.50, priceChange: 2.34, totalShares: 1_000_000, maxOwnershipPercent: 0.25),
        Stock(id: "dmd", name: "Diamond", symbol: "DMD", currentPrice: 412.00, priceChange: -8.20, totalShares: 1_000_000, maxOwnershipPercent: 0.25),
        Stock(id: "oil", name: "Oil", symbol: "OIL", currentPrice: 72.80, priceChange: 1.15, totalShares: 1_000_000, maxOwnershipPercent: 0.25),
        Stock(id: "slv", name: "Silver", symbol: "SLV", currentPrice: 24.90, priceChange: 0.45, totalShares: 1_000_000, maxOwnershipPercent: 0.25),
        Stock(id: "cl", name: "Coal", symbol: "CL", currentPrice: 56.20, priceChange: -1.80, totalShares: 1_000_000, maxOwnershipPercent: 0.25),
        Stock(id: "irn", name: "Iron", symbol: "IRN", currentPrice: 98.40, priceChange: 3.10, totalShares: 1_000_000, maxOwnershipPercent: 0.25)
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
                Self.stock(from: document)
            }

            // Use fake stocks for testing when Firestore has none
            let result = stocks.isEmpty ? Self.fakeStocks : stocks
            completion(.success(result))
        }
    }

    func observeStocks(_ onChange: @escaping (Result<[Stock], Error>) -> Void) {
        stopObservingStocks()
        stocksListener = db.collection("stockSymbols").addSnapshotListener { snapshot, error in
            if let error {
                onChange(.failure(error))
                return
            }
            let documents = snapshot?.documents ?? []
            let stocks = documents.compactMap { Self.stock(from: $0) }
            onChange(.success(stocks.isEmpty ? Self.fakeStocks : stocks))
        }
    }

    func stopObservingStocks() {
        stocksListener?.remove()
        stocksListener = nil
    }

    /// Returns fake price history for a stock for the given timeframe.
    func fetchPriceHistory(for stock: Stock, timeFrame: ChartTimeFrame, completion: @escaping ([StockPricePoint]) -> Void) {
        let historyRef = db
            .collection("stockSymbols")
            .document(stock.symbol)
            .collection("history")

        let start = startDate(for: timeFrame)
        // Pull newest points first so the chart always ends at "now".
        var query: Query = historyRef.order(by: "timestamp", descending: true)
        if let start {
            query = query.whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: start))
        }
        query = query.limit(to: maxPoints(for: timeFrame))

        query.getDocuments { snapshot, _ in
            let docs = snapshot?.documents ?? []
            let points: [StockPricePoint] = docs.compactMap { doc in
                let data = doc.data()
                guard let ts = data["timestamp"] as? Timestamp,
                      let price = data["price"] as? Double else { return nil }
                return StockPricePoint(
                    id: (data["id"] as? String) ?? doc.documentID,
                    timestamp: ts.dateValue(),
                    price: price
                )
            }
            let sorted = points.sorted { $0.timestamp < $1.timestamp }
            if sorted.isEmpty {
                // Fallback to fake data if history isn’t seeded yet.
                completion(Self.generateFakeHistory(symbol: stock.symbol, currentPrice: stock.currentPrice, timeFrame: timeFrame))
            } else {
                completion(Self.downsample(sorted, cap: Self.displayPointCap(for: timeFrame)))
            }
        }
    }

    func fetchRecentHistoryPoints(symbol: String, count: Int, completion: @escaping ([StockPricePoint]) -> Void) {
        let historyRef = db.collection("stockSymbols").document(symbol).collection("history")
        historyRef
            .order(by: "timestamp", descending: true)
            .limit(to: count)
            .getDocuments { snapshot, _ in
                let docs = snapshot?.documents ?? []
                let points: [StockPricePoint] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let ts = data["timestamp"] as? Timestamp,
                          let price = data["price"] as? Double else { return nil }
                    return StockPricePoint(
                        id: (data["id"] as? String) ?? doc.documentID,
                        timestamp: ts.dateValue(),
                        price: price
                    )
                }
                completion(points.sorted { $0.timestamp < $1.timestamp })
            }
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

private extension StockService {
    static func stock(from document: QueryDocumentSnapshot) -> Stock? {
        let data = document.data()
        guard
            let name = data["name"] as? String,
            let symbol = data["symbol"] as? String,
            let currentPrice = numberAsDouble(data["currentPrice"]),
            let priceChange = numberAsDouble(data["priceChange"])
        else { return nil }

        let totalShares = numberAsDouble(data["totalShares"]) ?? 1_000_000
        let maxOwnership = numberAsDouble(data["maxOwnershipPercent"]) ?? 0.25

        return Stock(
            id: (data["id"] as? String) ?? document.documentID,
            name: name,
            symbol: symbol,
            currentPrice: currentPrice,
            priceChange: priceChange,
            totalShares: totalShares,
            maxOwnershipPercent: max(0.01, min(1.0, maxOwnership))
        )
    }

    static func numberAsDouble(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        return nil
    }
}

extension ChartTimeFrame {
    /// (number of points, seconds between points)
    fileprivate func pointCountAndInterval() -> (Int, TimeInterval) {
        switch self {
        case .oneHour: return (60, 60)
        case .oneDay: return (48, 30 * 60)       // every 30 min
        case .oneWeek: return (28, 6 * 3600)     // every 6 hours
        case .allTime: return (90, 8 * 3600)     // every ~8 hours
        }
    }
}

extension StockService {
    private func startDate(for tf: ChartTimeFrame) -> Date? {
        let now = Date()
        switch tf {
        case .oneHour:
            return now.addingTimeInterval(-60 * 60)
        case .oneDay:
            return now.addingTimeInterval(-24 * 60 * 60)
        case .oneWeek:
            return now.addingTimeInterval(-7 * 24 * 60 * 60)
        case .allTime:
            return nil
        }
    }

    private func maxPoints(for tf: ChartTimeFrame) -> Int {
        // Max docs to fetch from Firestore for the chosen timeframe.
        // We downsample again before rendering so the chart stays smooth.
        switch tf {
        case .oneHour:
            return 180 // ~3 hours worth if tick cadence differs
        case .oneDay:
            return 2000
        case .oneWeek:
            return 12000 // up to a full week of minute ticks
        case .allTime:
            return 2000
        }
    }
}

private extension StockService {
    static func downsample(_ points: [StockPricePoint], cap: Int) -> [StockPricePoint] {
        guard points.count > cap, cap > 1 else { return points }
        let step = Double(points.count - 1) / Double(cap - 1)
        var out: [StockPricePoint] = []
        out.reserveCapacity(cap)

        var lastIdx: Int? = nil
        for i in 0..<cap {
            let idx = min(points.count - 1, max(0, Int(Double(i) * step)))
            if lastIdx != idx {
                out.append(points[idx])
                lastIdx = idx
            }
        }

        return out.count >= 2 ? out : points
    }

    static func displayPointCap(for tf: ChartTimeFrame) -> Int {
        switch tf {
        case .oneHour: return 110
        case .oneDay: return 240
        case .oneWeek: return 320
        case .allTime: return 520
        }
    }
}
