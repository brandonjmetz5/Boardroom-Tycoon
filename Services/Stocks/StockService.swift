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

    func fetchStocks(completion: @escaping (Result<[Stock], Error>) -> Void) {
        let stocksRef = db.collection("stockSymbols")

        stocksRef.getDocuments { snapshot, error in
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
                else {
                    return nil
                }

                return Stock(
                    id: id,
                    name: name,
                    symbol: symbol,
                    currentPrice: currentPrice,
                    priceChange: priceChange
                )
            }

            completion(.success(stocks))
        }
    }
}
