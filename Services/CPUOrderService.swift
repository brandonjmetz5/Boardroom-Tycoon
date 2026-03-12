//
//  CPUOrderService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class CPUOrderService {
    private let db = Firestore.firestore()

    func fetchCPUOrders(completion: @escaping (Result<[CPUOrder], Error>) -> Void) {
        let ordersRef = db.collection("cpuOrders")

        ordersRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let orders: [CPUOrder] = documents.compactMap { document in
                let data = document.data()

                guard
                    let id = data["id"] as? String,
                    let buyerType = data["buyerType"] as? String,
                    let itemID = data["itemID"] as? String,
                    let itemName = data["itemName"] as? String,
                    let quantityRemaining = data["quantityRemaining"] as? Double,
                    let pricePerUnit = data["pricePerUnit"] as? Double,
                    let isActive = data["isActive"] as? Bool
                else {
                    return nil
                }

                return CPUOrder(
                    id: id,
                    buyerType: buyerType,
                    itemID: itemID,
                    itemName: itemName,
                    quantityRemaining: quantityRemaining,
                    pricePerUnit: pricePerUnit,
                    isActive: isActive
                )
            }

            completion(.success(orders))
        }
    }
}
