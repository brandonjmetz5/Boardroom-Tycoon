//
//  StockPositionService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class StockPositionService {
    private let db = Firestore.firestore()

    func fetchStockPositions(for userID: String, completion: @escaping (Result<[StockPosition], Error>) -> Void) {
        let positionsRef = db.collection("playerProfiles").document(userID).collection("stockPositions")

        positionsRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let positions: [StockPosition] = documents.compactMap { document in
                let data = document.data()

                guard
                    let id = data["id"] as? String,
                    let symbol = data["symbol"] as? String,
                    let sharesOwned = data["sharesOwned"] as? Double,
                    let averageCost = data["averageCost"] as? Double
                else {
                    return nil
                }

                return StockPosition(
                    id: id,
                    symbol: symbol,
                    sharesOwned: sharesOwned,
                    averageCost: averageCost
                )
            }

            completion(.success(positions))
        }
    }
}
