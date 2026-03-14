//
//  StockService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

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

    /// Returns fake price history for a stock (last 30 days, random walk from current price).
    func fetchPriceHistory(for stock: Stock, completion: @escaping ([StockPricePoint]) -> Void) {
        let points = Self.generateFakeHistory(symbol: stock.symbol, currentPrice: stock.currentPrice, count: 31)
        completion(points)
    }

    /// Generates fake daily closing prices going backward from current price.
    static func generateFakeHistory(symbol: String, currentPrice: Double, count: Int = 31) -> [StockPricePoint] {
        var points: [StockPricePoint] = []
        let calendar = Calendar.current
        var price = currentPrice
        var date = calendar.startOfDay(for: Date())

        for i in 0..<count {
            let id = "\(symbol)-\(i)"
            points.append(StockPricePoint(id: id, timestamp: date, price: price))
            // Walk backward one day and adjust price with small random change
            guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
            let change = Double.random(in: -0.02...0.02)
            price = max(0.01, price / (1 + change))
        }

        return points.sorted { $0.timestamp < $1.timestamp }
    }
}
