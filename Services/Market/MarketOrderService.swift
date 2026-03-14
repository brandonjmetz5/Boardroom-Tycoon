//
//  MarketOrderService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class MarketOrderService {
    private let db = Firestore.firestore()

    func fetchMarketOrders(completion: @escaping (Result<[MarketOrder], Error>) -> Void) {
        let ordersRef = db.collection("marketOrders")

        ordersRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let orders: [MarketOrder] = documents.compactMap { document in
                let data = document.data()

                guard
                    let id = data["id"] as? String,
                    let buyerID = data["buyerID"] as? String,
                    let buyerName = data["buyerName"] as? String,
                    let itemID = data["itemID"] as? String,
                    let itemName = data["itemName"] as? String,
                    let categoryRawValue = data["category"] as? String,
                    let category = ItemCategory(rawValue: categoryRawValue),
                    let isFractional = data["isFractional"] as? Bool,
                    let quantityWanted = data["quantityWanted"] as? Double,
                    let pricePerUnit = data["pricePerUnit"] as? Double,
                    let isActive = data["isActive"] as? Bool
                else {
                    return nil
                }

                return MarketOrder(
                    id: id,
                    buyerID: buyerID,
                    buyerName: buyerName,
                    itemID: itemID,
                    itemName: itemName,
                    category: category,
                    isFractional: isFractional,
                    quantityWanted: quantityWanted,
                    pricePerUnit: pricePerUnit,
                    isActive: isActive
                )
            }

            completion(.success(orders))
        }
    }
}
