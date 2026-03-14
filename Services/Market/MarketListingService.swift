//
//  MarketListingService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class MarketListingService {
    private let db = Firestore.firestore()

    func fetchMarketListings(completion: @escaping (Result<[MarketListing], Error>) -> Void) {
        let listingsRef = db.collection("marketListings")

        listingsRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let listings: [MarketListing] = documents.compactMap { document in
                let data = document.data()

                guard
                    let id = data["id"] as? String,
                    let itemID = data["itemID"] as? String,
                    let itemName = data["itemName"] as? String,
                    let categoryRawValue = data["category"] as? String,
                    let category = ItemCategory(rawValue: categoryRawValue),
                    let isFractional = data["isFractional"] as? Bool,
                    let quantity = data["quantity"] as? Double,
                    let pricePerUnit = data["pricePerUnit"] as? Double,
                    let sellerName = data["sellerName"] as? String
                else {
                    return nil
                }

                let item = Item(
                    id: itemID,
                    name: itemName,
                    category: category,
                    isFractional: isFractional
                )

                return MarketListing(
                    id: id,
                    item: item,
                    quantity: quantity,
                    pricePerUnit: pricePerUnit,
                    sellerName: sellerName
                )
            }

            completion(.success(listings))
        }
    }
}
