//
//  MarketListingService.swift
//  Boardroom Tycoon
//
//  Create, fetch, buy (partial), and cancel resource listings.
//

import Foundation
import FirebaseFirestore

final class MarketListingService {
    private let db = Firestore.firestore()

    private var listingsRef: CollectionReference { db.collection("marketListings") }

    // MARK: - Fetch all (filter and sort in memory: optional resource, min quality; sort by price ascending)

    func fetchAllListings(completion: @escaping (Result<[MarketListing], Error>) -> Void) {
        listingsRef.getDocuments { [weak self] snapshot, error in
            guard let self else { return }
            if let error = error {
                completion(.failure(error))
                return
            }
            let listings = (snapshot?.documents ?? []).compactMap { self.listing(from: $0) }
            completion(.success(listings))
        }
    }

    // MARK: - Create (deduct from seller inventory, create listing)

    func createListing(
        sellerUserID: String,
        sellerName: String?,
        resourceID: String,
        resourceName: String,
        resourceCategory: String,
        quality: Int,
        quantity: Double,
        pricePerUnit: Double,
        isFractional: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard quantity > 0, pricePerUnit > 0 else {
            completion(.failure(NSError(domain: "MarketListingService", code: 7001, userInfo: [NSLocalizedDescriptionKey: "Quantity and price must be positive."])))
            return
        }

        let inventoryDocID = quality > 1 ? "\(resourceID)-q\(quality)" : resourceID
        let sellerInvRef = db.collection("playerProfiles").document(sellerUserID).collection("inventory").document(inventoryDocID)

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                let invSnap = try transaction.getDocument(sellerInvRef)
                guard let invData = invSnap.data(),
                      let currentQty = invData["quantity"] as? Double else {
                    errorPointer?.pointee = NSError(domain: "MarketListingService", code: 7002, userInfo: [NSLocalizedDescriptionKey: "Inventory not found or empty."])
                    return nil
                }
                if currentQty < quantity {
                    errorPointer?.pointee = NSError(domain: "MarketListingService", code: 7003, userInfo: [NSLocalizedDescriptionKey: "Insufficient quantity. You have \(Int(currentQty)), listing \(Int(quantity))."])
                    return nil
                }

                let listingRef = self.listingsRef.document()
                let listingData: [String: Any] = [
                    "id": listingRef.documentID,
                    "sellerUserID": sellerUserID,
                    "sellerName": sellerName as Any,
                    "resourceID": resourceID,
                    "resourceName": resourceName,
                    "resourceCategory": resourceCategory,
                    "quality": max(1, quality),
                    "quantity": quantity,
                    "pricePerUnit": pricePerUnit,
                    "isFractional": isFractional,
                    "createdAt": Timestamp(date: Date())
                ]
                transaction.setData(listingData, forDocument: listingRef)

                let newQty = currentQty - quantity
                if newQty <= 0 {
                    transaction.deleteDocument(sellerInvRef)
                } else {
                    var updated = invData
                    updated["quantity"] = newQty
                    transaction.setData(updated, forDocument: sellerInvRef)
                }
                return nil
            } catch let e as NSError {
                errorPointer?.pointee = e
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

    // MARK: - Buy (full listing: transfer all quantity from listing to buyer, 3% fee)

    func buyFromListing(
        for buyerUserID: String,
        listing: MarketListing,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let listingRef = listingsRef.document(listing.id)
        let feePercent = MarketCatalog.buyOrderFeePercent

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                // ---- READS: listing, profiles, and buyer inventory ----
                let listSnap = try transaction.getDocument(listingRef)
                guard let listData = listSnap.data() else {
                    errorPointer?.pointee = NSError(domain: "MarketListingService", code: 7011, userInfo: [NSLocalizedDescriptionKey: "Listing not found."])
                    return nil
                }
                let available = listData["quantity"] as? Double ?? 0
                if available <= 0 {
                    errorPointer?.pointee = NSError(domain: "MarketListingService", code: 7012, userInfo: [NSLocalizedDescriptionKey: "Listing has already been sold."])
                    return nil
                }
                let pricePerUnit = listData["pricePerUnit"] as? Double ?? 0
                let quantity = available
                let total = quantity * pricePerUnit
                let sellerUserID = listData["sellerUserID"] as? String ?? ""
                let resourceID = listData["resourceID"] as? String ?? ""
                let resourceName = listData["resourceName"] as? String ?? ""
                let resourceCategory = listData["resourceCategory"] as? String ?? ""
                let quality = (listData["quality"] as? Int) ?? 1
                let isFractional = listData["isFractional"] as? Bool ?? false
                let inventoryDocID = quality > 1 ? "\(resourceID)-q\(quality)" : resourceID

                let buyerProfileRef = self.db.collection("playerProfiles").document(buyerUserID)
                let sellerProfileRef = self.db.collection("playerProfiles").document(sellerUserID)
                let buyerInvRef = buyerProfileRef.collection("inventory").document(inventoryDocID)

                let buyerProfileSnap = try transaction.getDocument(buyerProfileRef)
                let sellerProfileSnap = try transaction.getDocument(sellerProfileRef)
                let buyerInvSnap = try transaction.getDocument(buyerInvRef)

                let buyerData = buyerProfileSnap.data() ?? [:]
                let sellerData = sellerProfileSnap.data() ?? [:]
                let buyerCash = buyerData["cash"] as? Double ?? 0
                let sellerCash = sellerData["cash"] as? Double ?? 0

                if buyerCash < total {
                    errorPointer?.pointee = NSError(domain: "MarketListingService", code: 7013, userInfo: [NSLocalizedDescriptionKey: "Not enough cash. Need \(String(format: "$%.2f", total)), have \(String(format: "$%.2f", buyerCash))."])
                    return nil
                }

                let fee = total * (feePercent / 100)
                let netToSeller = total - fee

                // ---- WRITES: all reads are above ----
                // Mark sold (so backend can distinguish from cancel), then delete listing.
                transaction.updateData([
                    "soldAt": Timestamp(date: Date()),
                    "soldToUserID": buyerUserID
                ], forDocument: listingRef)
                transaction.deleteDocument(listingRef)

                // Buyer inventory
                let buyerInvData = buyerInvSnap.data()
                let buyerQty = (buyerInvData?["quantity"] as? Double) ?? 0
                let newBuyerQty = buyerQty + quantity
                let buyerDoc: [String: Any] = (buyerInvData ?? [
                    "id": inventoryDocID,
                    "name": resourceName,
                    "category": resourceCategory,
                    "isFractional": isFractional
                ]).merging(["quantity": newBuyerQty]) { _, new in new }
                transaction.setData(buyerDoc, forDocument: buyerInvRef)

                transaction.updateData(["cash": buyerCash - total], forDocument: buyerProfileRef)
                transaction.updateData(["cash": sellerCash + netToSeller], forDocument: sellerProfileRef)

                return nil
            } catch let e as NSError {
                errorPointer?.pointee = e
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

    // MARK: - Cancel (return quantity to seller, delete listing)

    func cancelListing(listingID: String, sellerUserID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let listingRef = listingsRef.document(listingID)

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                let listSnap = try transaction.getDocument(listingRef)
                guard let listData = listSnap.data() else {
                    errorPointer?.pointee = NSError(domain: "MarketListingService", code: 7020, userInfo: [NSLocalizedDescriptionKey: "Listing not found."])
                    return nil
                }
                let sid = listData["sellerUserID"] as? String ?? ""
                guard sid == sellerUserID else {
                    errorPointer?.pointee = NSError(domain: "MarketListingService", code: 7021, userInfo: [NSLocalizedDescriptionKey: "Only the seller can cancel this listing."])
                    return nil
                }
                let quantity = listData["quantity"] as? Double ?? 0
                let resourceID = listData["resourceID"] as? String ?? ""
                let resourceName = listData["resourceName"] as? String ?? ""
                let resourceCategory = listData["resourceCategory"] as? String ?? ""
                let quality = (listData["quality"] as? Int) ?? 1
                let isFractional = listData["isFractional"] as? Bool ?? false
                let inventoryDocID = quality > 1 ? "\(resourceID)-q\(quality)" : resourceID

                let sellerInvRef = self.db.collection("playerProfiles").document(sellerUserID).collection("inventory").document(inventoryDocID)
                let invSnap = try transaction.getDocument(sellerInvRef)
                let invData = invSnap.data()
                let currentQty = (invData?["quantity"] as? Double) ?? 0
                let newQty = currentQty + quantity
                let doc: [String: Any] = (invData ?? [
                    "id": inventoryDocID,
                    "name": resourceName,
                    "category": resourceCategory,
                    "isFractional": isFractional
                ]).merging(["quantity": newQty]) { _, new in new }
                transaction.setData(doc, forDocument: sellerInvRef)

                // Mark cancelled (so backend can ignore this delete), then delete listing.
                transaction.updateData([
                    "cancelledAt": Timestamp(date: Date()),
                    "cancelledByUserID": sellerUserID
                ], forDocument: listingRef)
                transaction.deleteDocument(listingRef)
                return nil
            } catch let e as NSError {
                errorPointer?.pointee = e
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

    // MARK: - Parser

    private func listing(from document: DocumentSnapshot) -> MarketListing? {
        guard let data = document.data() else { return nil }
        let id = data["id"] as? String ?? document.documentID
        let sellerUserID = data["sellerUserID"] as? String ?? ""
        let sellerName = data["sellerName"] as? String
        let itemID = data["resourceID"] as? String ?? data["itemID"] as? String ?? ""
        let itemName = data["resourceName"] as? String ?? data["itemName"] as? String ?? ""
        let categoryRaw = data["resourceCategory"] as? String ?? data["category"] as? String ?? ""
        let category = ItemCategory(rawValue: categoryRaw) ?? .rawMaterial
        let isFractional = data["isFractional"] as? Bool ?? false
        let quality = (data["quality"] as? Int) ?? 1
        let quantity = data["quantity"] as? Double ?? 0
        let pricePerUnit = data["pricePerUnit"] as? Double ?? 0

        let item = Item(id: itemID, name: itemName, category: category, isFractional: isFractional)
        return MarketListing(
            id: id,
            sellerUserID: sellerUserID,
            sellerName: sellerName,
            item: item,
            quality: max(1, quality),
            quantity: quantity,
            pricePerUnit: pricePerUnit
        )
    }
}
