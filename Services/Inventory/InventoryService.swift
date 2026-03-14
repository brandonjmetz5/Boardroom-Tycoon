//
//  InventoryService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation
import FirebaseFirestore

final class InventoryService {
    private let db = Firestore.firestore()

    func createStarterInventoryIfNeeded(for userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let inventoryRef = db.collection("playerProfiles").document(userID).collection("inventory")

        inventoryRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let snapshot = snapshot, !snapshot.documents.isEmpty {
                completion(.success(()))
                return
            }

            let starterItems: [[String: Any]] = [
                [
                    "id": "gold-bar",
                    "name": "Gold Bar",
                    "category": "Refined Material",
                    "isFractional": true,
                    "quantity": 0.75
                ],
                [
                    "id": "fuel-cell",
                    "name": "Fuel Cell",
                    "category": "Fuel",
                    "isFractional": false,
                    "quantity": 12.0
                ],
                [
                    "id": "cut-diamond",
                    "name": "Cut Diamond",
                    "category": "Refined Material",
                    "isFractional": false,
                    "quantity": 3.0
                ],
                [
                    "id": "steel",
                    "name": "Steel",
                    "category": "Building Material",
                    "isFractional": false,
                    "quantity": 5.0
                ]
            ]

            let batch = self.db.batch()

            for itemData in starterItems {
                guard let id = itemData["id"] as? String else { continue }
                let docRef = inventoryRef.document(id)
                batch.setData(itemData, forDocument: docRef)
            }

            batch.commit { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    func fetchInventory(for userID: String, completion: @escaping (Result<[InventoryItem], Error>) -> Void) {
        let inventoryRef = db.collection("playerProfiles").document(userID).collection("inventory")

        inventoryRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let inventoryItems: [InventoryItem] = documents.compactMap { document in
                let data = document.data()

                guard
                    let id = data["id"] as? String,
                    let name = data["name"] as? String,
                    let categoryRawValue = data["category"] as? String,
                    let category = ItemCategory(rawValue: categoryRawValue),
                    let isFractional = data["isFractional"] as? Bool,
                    let quantity = data["quantity"] as? Double
                else {
                    return nil
                }

                let item = Item(
                    id: id,
                    name: name,
                    category: category,
                    isFractional: isFractional
                )

                return InventoryItem(
                    id: document.documentID,
                    item: item,
                    quantity: quantity
                )
            }

            completion(.success(inventoryItems))
        }
    }
}
