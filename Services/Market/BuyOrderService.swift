//
//  BuyOrderService.swift
//  Boardroom Tycoon
//
//  Post, cancel, list, and fulfill buy orders. Escrow buyer cash on post; 3% fee on fulfillment.
//

import Foundation
import FirebaseFirestore

final class BuyOrderService {
    private let db = Firestore.firestore()

    private var buyOrdersRef: CollectionReference { db.collection("marketBuyOrders") }

    // MARK: - Post

    /// Post a new buy order with one or more resource lines. Deducts totalPrice from buyer (escrow); creates open order.
    func postBuyOrder(
        buyerUserID: String,
        buyerName: String?,
        lines: [BuyOrderLine],
        totalPrice: Double,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard !lines.isEmpty else {
            completion(.failure(NSError(domain: "BuyOrderService", code: 6001, userInfo: [NSLocalizedDescriptionKey: "Add at least one resource line."])))
            return
        }
        guard lines.allSatisfy({ $0.quantity > 0 }), totalPrice > 0 else {
            completion(.failure(NSError(domain: "BuyOrderService", code: 6001, userInfo: [NSLocalizedDescriptionKey: "Quantities and total price must be positive."])))
            return
        }

        let feePercent = MarketCatalog.buyOrderFeePercent
        let netToSeller = totalPrice * (1 - feePercent / 100)

        let profileRef = db.collection("playerProfiles").document(buyerUserID)
        let linesData = lines.map { line -> [String: Any] in
            [
                "resourceID": line.resourceID,
                "resourceName": line.resourceName,
                "resourceCategory": line.resourceCategory,
                "resourceQuality": max(1, line.resourceQuality),
                "quantity": line.quantity,
                "isFractional": line.isFractional
            ]
        }

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                let profileSnap = try transaction.getDocument(profileRef)
                guard let profileData = profileSnap.data(),
                      let currentCash = profileData["cash"] as? Double else {
                    errorPointer?.pointee = NSError(domain: "BuyOrderService", code: 6002, userInfo: [NSLocalizedDescriptionKey: "Player profile not found."])
                    return nil
                }
                if currentCash < totalPrice {
                    errorPointer?.pointee = NSError(domain: "BuyOrderService", code: 6003, userInfo: [NSLocalizedDescriptionKey: "Not enough cash. You need \(Int(totalPrice)) but have \(Int(currentCash))."])
                    return nil
                }

                let orderRef = self.buyOrdersRef.document()
                let now = Date()
                let orderData: [String: Any] = [
                    "id": orderRef.documentID,
                    "buyerUserID": buyerUserID,
                    "buyerName": buyerName as Any,
                    "lines": linesData,
                    "totalPrice": totalPrice,
                    "feePercent": feePercent,
                    "netToSeller": netToSeller,
                    "status": "open",
                    "createdAt": Timestamp(date: now),
                    "filledAt": NSNull(),
                    "filledByUserID": NSNull()
                ]
                transaction.setData(orderData, forDocument: orderRef)
                transaction.updateData(["cash": currentCash - totalPrice], forDocument: profileRef)
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

    // MARK: - Cancel

    /// Cancel an open buy order and refund the buyer.
    func cancelBuyOrder(orderID: String, buyerUserID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let orderRef = buyOrdersRef.document(orderID)
        let profileRef = db.collection("playerProfiles").document(buyerUserID)

        db.runTransaction({ transaction, errorPointer in
            do {
                let orderSnap = try transaction.getDocument(orderRef)
                guard let orderData = orderSnap.data() else {
                    errorPointer?.pointee = NSError(domain: "BuyOrderService", code: 6010, userInfo: [NSLocalizedDescriptionKey: "Buy order not found."])
                    return nil
                }
                let status = orderData["status"] as? String ?? ""
                guard status == "open" else {
                    errorPointer?.pointee = NSError(domain: "BuyOrderService", code: 6011, userInfo: [NSLocalizedDescriptionKey: "Order is no longer open and cannot be cancelled."])
                    return nil
                }
                let obuyer = orderData["buyerUserID"] as? String ?? ""
                guard obuyer == buyerUserID else {
                    errorPointer?.pointee = NSError(domain: "BuyOrderService", code: 6012, userInfo: [NSLocalizedDescriptionKey: "Only the buyer can cancel this order."])
                    return nil
                }
                let totalPrice = orderData["totalPrice"] as? Double ?? 0

                let profileSnap = try transaction.getDocument(profileRef)
                let profileData = profileSnap.data() ?? [:]
                let cash = profileData["cash"] as? Double ?? 0

                transaction.updateData(["status": "cancelled"], forDocument: orderRef)
                transaction.updateData(["cash": cash + totalPrice], forDocument: profileRef)
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

    // MARK: - Fetch

    /// Fetch open buy orders, optionally filtered by resource category, resource ID, quality. Sorted by createdAt desc.
    func fetchOpenBuyOrders(
        resourceCategory: String? = nil,
        resourceID: String? = nil,
        resourceQuality: Int? = nil,
        completion: @escaping (Result<[BuyOrder], Error>) -> Void
    ) {
        // Query without orderBy to avoid requiring a composite index; sort in memory.
        buyOrdersRef
            .whereField("status", isEqualTo: "open")
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    completion(.failure(error))
                    return
                }
                var orders = (snapshot?.documents ?? []).compactMap { self.buyOrder(from: $0) }
                orders.sort { $0.createdAt > $1.createdAt }
                if let cat = resourceCategory, !cat.isEmpty {
                    orders = orders.filter { $0.anyLine(matchesCategory: cat, resourceID: resourceID, quality: resourceQuality) }
                }
                if let rid = resourceID, !rid.isEmpty {
                    orders = orders.filter { $0.anyLine(matchesCategory: resourceCategory, resourceID: rid, quality: resourceQuality) }
                }
                if let q = resourceQuality, q > 0 {
                    orders = orders.filter { $0.anyLine(matchesCategory: resourceCategory, resourceID: resourceID, quality: q) }
                }
                completion(.success(orders))
            }
    }

    // MARK: - Fulfill

    /// Fulfill an open buy order: move inventory from seller to buyer, pay seller (net of fee). First valid fulfillment wins.
    func fulfillBuyOrder(orderID: String, sellerUserID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let orderRef = buyOrdersRef.document(orderID)
        let sellerProfileRef = db.collection("playerProfiles").document(sellerUserID)
        let sellerInventoryRef = db.collection("playerProfiles").document(sellerUserID).collection("inventory")

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                let orderSnap = try transaction.getDocument(orderRef)
                guard let orderData = orderSnap.data() else {
                    errorPointer?.pointee = NSError(domain: "BuyOrderService", code: 6020, userInfo: [NSLocalizedDescriptionKey: "Buy order not found."])
                    return nil
                }
                let status = orderData["status"] as? String ?? ""
                guard status == "open" else {
                    errorPointer?.pointee = NSError(domain: "BuyOrderService", code: 6021, userInfo: [NSLocalizedDescriptionKey: "Order already filled or cancelled."])
                    return nil
                }

                let buyerUserID = orderData["buyerUserID"] as? String ?? ""
                let totalPrice = orderData["totalPrice"] as? Double ?? 0
                let netToSeller = orderData["netToSeller"] as? Double ?? (totalPrice * 0.97)
                let orderLines = self.parseLines(from: orderData)

                let buyerProfRef = self.db.collection("playerProfiles").document(buyerUserID)

                // Validate seller has every line
                for line in orderLines {
                    let sellerInvRef = sellerInventoryRef.document(line.resourceInventoryDocID)
                    let sellerInvSnap = try transaction.getDocument(sellerInvRef)
                    let sellerQty = (sellerInvSnap.data()?["quantity"] as? Double) ?? 0
                    if sellerQty < line.quantity {
                        errorPointer?.pointee = NSError(domain: "BuyOrderService", code: 6022, userInfo: [NSLocalizedDescriptionKey: "Insufficient \(line.resourceName) (Q\(line.resourceQuality)). You have \(Int(sellerQty)), need \(Int(line.quantity))."])
                        return nil
                    }
                }

                let sellerProfileSnap = try transaction.getDocument(sellerProfileRef)
                let sellerProfileData = sellerProfileSnap.data() ?? [:]
                let sellerCash = sellerProfileData["cash"] as? Double ?? 0

                // Update order
                transaction.updateData([
                    "status": "filled",
                    "filledAt": Timestamp(date: Date()),
                    "filledByUserID": sellerUserID
                ], forDocument: orderRef)

                // For each line: deduct from seller, add to buyer
                for line in orderLines {
                    let sellerInvRef = sellerInventoryRef.document(line.resourceInventoryDocID)
                    let buyerInvRef = buyerProfRef.collection("inventory").document(line.resourceInventoryDocID)
                    let sellerInvSnap = try transaction.getDocument(sellerInvRef)
                    let sellerInvData = sellerInvSnap.data()
                    let sellerQty = (sellerInvData?["quantity"] as? Double) ?? 0
                    let newSellerQty = sellerQty - line.quantity
                    if newSellerQty <= 0 {
                        transaction.deleteDocument(sellerInvRef)
                    } else {
                        var updated = sellerInvData ?? ["id": line.resourceInventoryDocID, "name": line.resourceName, "category": line.resourceCategory, "isFractional": line.isFractional]
                        updated["quantity"] = newSellerQty
                        transaction.setData(updated, forDocument: sellerInvRef)
                    }
                    let buyerInvSnap = try transaction.getDocument(buyerInvRef)
                    let buyerInvData = buyerInvSnap.data()
                    let buyerQty = (buyerInvData?["quantity"] as? Double) ?? 0
                    let newBuyerQty = buyerQty + line.quantity
                    let buyerDoc: [String: Any] = (buyerInvData ?? [
                        "id": line.resourceInventoryDocID,
                        "name": line.resourceName,
                        "category": line.resourceCategory,
                        "isFractional": line.isFractional
                    ]).merging(["quantity": newBuyerQty]) { _, new in new }
                    transaction.setData(buyerDoc, forDocument: buyerInvRef)
                }

                // Seller cash
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

    // MARK: - Helpers

    /// Parse order lines from doc: either "lines" array or legacy single resource fields.
    private func parseLines(from data: [String: Any]) -> [BuyOrderLine] {
        if let arr = data["lines"] as? [[String: Any]], !arr.isEmpty {
            return arr.compactMap { dict in
                guard let resourceID = dict["resourceID"] as? String,
                      let resourceName = dict["resourceName"] as? String,
                      let resourceCategory = dict["resourceCategory"] as? String,
                      let quantity = dict["quantity"] as? Double, quantity > 0 else { return nil }
                let resourceQuality = (dict["resourceQuality"] as? Int) ?? 1
                let isFractional = dict["isFractional"] as? Bool ?? false
                return BuyOrderLine(
                    resourceID: resourceID,
                    resourceName: resourceName,
                    resourceCategory: resourceCategory,
                    resourceQuality: max(1, resourceQuality),
                    quantity: quantity,
                    isFractional: isFractional
                )
            }
        }
        // Legacy single-resource doc
        guard let resourceID = data["resourceID"] as? String, !resourceID.isEmpty else { return [] }
        let resourceName = data["resourceName"] as? String ?? ""
        let resourceCategory = data["resourceCategory"] as? String ?? ""
        let resourceQuality = (data["resourceQuality"] as? Int) ?? 1
        let quantity = data["quantity"] as? Double ?? 0
        let isFractional = data["isFractional"] as? Bool ?? false
        return [BuyOrderLine(
            resourceID: resourceID,
            resourceName: resourceName,
            resourceCategory: resourceCategory,
            resourceQuality: max(1, resourceQuality),
            quantity: quantity,
            isFractional: isFractional
        )]
    }

    private func buyOrder(from document: DocumentSnapshot) -> BuyOrder? {
        guard let data = document.data() else { return nil }
        let id = data["id"] as? String ?? document.documentID
        let buyerUserID = data["buyerUserID"] as? String ?? ""
        let buyerName = data["buyerName"] as? String
        let totalPrice = data["totalPrice"] as? Double ?? 0
        let feePercent = data["feePercent"] as? Double ?? MarketCatalog.buyOrderFeePercent
        let netToSeller = data["netToSeller"] as? Double ?? (totalPrice * (1 - feePercent / 100))
        let status = data["status"] as? String ?? "open"
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let filledAt = (data["filledAt"] as? Timestamp)?.dateValue()
        let filledByUserID = data["filledByUserID"] as? String
        let lines = parseLines(from: data)
        guard !lines.isEmpty else { return nil }

        return BuyOrder(
            id: id,
            buyerUserID: buyerUserID,
            buyerName: buyerName,
            lines: lines,
            totalPrice: totalPrice,
            feePercent: feePercent,
            netToSeller: netToSeller,
            status: status,
            createdAt: createdAt,
            filledAt: filledAt,
            filledByUserID: filledByUserID
        )
    }
}
