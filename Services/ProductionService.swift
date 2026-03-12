//
//  ProductionService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class ProductionService {
    private let db = Firestore.firestore()

    func startProduction(for userID: String, buildingID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let buildingRef = db.collection("playerProfiles").document(userID).collection("buildings").document(buildingID)

        let startedAt = Date()
        //let endsAt = startedAt.addingTimeInterval(60 * 60) // 60 minutes
        let endsAt = startedAt.addingTimeInterval(10) // temporary 10 seconds for testing
        let pendingOutputQuantity = 10.0

        buildingRef.updateData([
            "isProducing": true,
            "productionStartedAt": Timestamp(date: startedAt),
            "productionEndsAt": Timestamp(date: endsAt),
            "pendingOutputQuantity": pendingOutputQuantity
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func collectProduction(for userID: String, buildingID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let buildingRef = db.collection("playerProfiles").document(userID).collection("buildings").document(buildingID)
        let inventoryRef = db.collection("playerProfiles").document(userID).collection("inventory").document("raw-gold")

        db.runTransaction({ transaction, errorPointer in
            do {
                let buildingSnapshot = try transaction.getDocument(buildingRef)
                let inventorySnapshot = try transaction.getDocument(inventoryRef)

                guard
                    let buildingData = buildingSnapshot.data(),
                    let pendingOutputQuantity = buildingData["pendingOutputQuantity"] as? Double,
                    let isProducing = buildingData["isProducing"] as? Bool,
                    let productionEndsAtTimestamp = buildingData["productionEndsAt"] as? Timestamp
                else {
                    let error = NSError(
                        domain: "ProductionService",
                        code: 2001,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid building production data."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if !isProducing {
                    let error = NSError(
                        domain: "ProductionService",
                        code: 2002,
                        userInfo: [NSLocalizedDescriptionKey: "This building is not producing."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if productionEndsAtTimestamp.dateValue() > Date() {
                    let error = NSError(
                        domain: "ProductionService",
                        code: 2003,
                        userInfo: [NSLocalizedDescriptionKey: "Production is not finished yet."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let currentQuantity = inventorySnapshot.data()?["quantity"] as? Double ?? 0.0

                let inventoryData: [String: Any] = [
                    "id": "raw-gold",
                    "name": "Raw Gold",
                    "category": "Raw Material",
                    "isFractional": false,
                    "quantity": currentQuantity + pendingOutputQuantity
                ]

                transaction.setData(inventoryData, forDocument: inventoryRef)
                transaction.updateData([
                    "isProducing": false,
                    "productionStartedAt": NSNull(),
                    "productionEndsAt": NSNull(),
                    "pendingOutputQuantity": 0.0
                ], forDocument: buildingRef)

                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
