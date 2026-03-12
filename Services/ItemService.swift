//
//  ItemService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class ItemService {
    private let db = Firestore.firestore()

    func fetchItems(completion: @escaping (Result<[Item], Error>) -> Void) {
        let itemsRef = db.collection("items")

        itemsRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let items: [Item] = documents.compactMap { document in
                let data = document.data()

                guard
                    let id = data["id"] as? String,
                    let name = data["name"] as? String,
                    let categoryRawValue = data["category"] as? String,
                    let category = ItemCategory(rawValue: categoryRawValue),
                    let isFractional = data["isFractional"] as? Bool
                else {
                    return nil
                }

                return Item(
                    id: id,
                    name: name,
                    category: category,
                    isFractional: isFractional
                )
            }

            completion(.success(items))
        }
    }
}
