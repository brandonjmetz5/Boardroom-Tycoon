//
//  StockPositionService.swift
//  Boardroom Tycoon
//
//  Fetches positions and runs buy/sell with atomic profile cash + position updates.
//

import Foundation
import FirebaseFirestore

final class StockPositionService {
    private let db = Firestore.firestore()

    /// Document ID for a position is the stock symbol (one position per symbol per player).
    private func positionRef(userID: String, symbol: String) -> DocumentReference {
        db.collection("playerProfiles").document(userID).collection("stockPositions").document(symbol)
    }

    private func profileRef(userID: String) -> DocumentReference {
        db.collection("playerProfiles").document(userID)
    }

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
                    let symbol = data["symbol"] as? String,
                    let sharesOwned = data["sharesOwned"] as? Double,
                    let averageCost = data["averageCost"] as? Double
                else {
                    return nil
                }
                let id = data["id"] as? String ?? document.documentID
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

    /// Buy shares: deducts cash from profile and creates/updates position. Atomic.
    func buyStock(
        userID: String,
        symbol: String,
        shares: Double,
        pricePerShare: Double,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard shares > 0, pricePerShare > 0 else {
            completion(.failure(NSError(domain: "StockPositionService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid shares or price."])))
            return
        }

        let profileRef = profileRef(userID: userID)
        let positionRef = positionRef(userID: userID, symbol: symbol)
        let cost = shares * pricePerShare

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                let profileSnap = try transaction.getDocument(profileRef)
                guard let profileData = profileSnap.data(),
                      let cash = profileData["cash"] as? Double else {
                    errorPointer?.pointee = NSError(domain: "StockPositionService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found."])
                    return nil
                }
                if cash < cost {
                    errorPointer?.pointee = NSError(domain: "StockPositionService", code: 402, userInfo: [NSLocalizedDescriptionKey: "Not enough cash. You need \(String(format: "%.2f", cost)) but have \(String(format: "%.2f", cash))."])
                    return nil
                }

                var existingShares: Double = 0
                var existingAvg: Double = 0
                let positionSnap = try transaction.getDocument(positionRef)
                if let posData = positionSnap.data() {
                    existingShares = posData["sharesOwned"] as? Double ?? 0
                    existingAvg = posData["averageCost"] as? Double ?? 0
                }

                let newShares = existingShares + shares
                let newAvgCost = existingShares > 0
                    ? ((existingShares * existingAvg) + (shares * pricePerShare)) / newShares
                    : pricePerShare

                transaction.updateData(["cash": cash - cost], forDocument: profileRef)
                transaction.setData([
                    "id": symbol,
                    "symbol": symbol,
                    "sharesOwned": newShares,
                    "averageCost": newAvgCost
                ], forDocument: positionRef)

                return nil
            } catch {
                errorPointer?.pointee = error as NSError
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

    /// Sell shares: adds proceeds to profile and reduces/deletes position. Atomic.
    func sellStock(
        userID: String,
        symbol: String,
        shares: Double,
        pricePerShare: Double,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard shares > 0, pricePerShare > 0 else {
            completion(.failure(NSError(domain: "StockPositionService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid shares or price."])))
            return
        }

        let profileRef = profileRef(userID: userID)
        let positionRef = positionRef(userID: userID, symbol: symbol)
        let proceeds = shares * pricePerShare

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                let profileSnap = try transaction.getDocument(profileRef)
                guard let profileData = profileSnap.data(),
                      let cash = profileData["cash"] as? Double else {
                    errorPointer?.pointee = NSError(domain: "StockPositionService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found."])
                    return nil
                }

                let positionSnap = try transaction.getDocument(positionRef)
                guard let posData = positionSnap.data(),
                      let sharesOwned = posData["sharesOwned"] as? Double else {
                    errorPointer?.pointee = NSError(domain: "StockPositionService", code: 404, userInfo: [NSLocalizedDescriptionKey: "You don't own any \(symbol)."])
                    return nil
                }
                if sharesOwned < shares {
                    errorPointer?.pointee = NSError(domain: "StockPositionService", code: 400, userInfo: [NSLocalizedDescriptionKey: "You only own \(String(format: "%.2f", sharesOwned)) shares. Cannot sell \(String(format: "%.2f", shares))."])
                    return nil
                }

                let newShares = sharesOwned - shares
                transaction.updateData(["cash": cash + proceeds], forDocument: profileRef)
                if newShares <= 0 {
                    transaction.deleteDocument(positionRef)
                } else {
                    let avgCost = posData["averageCost"] as? Double ?? 0
                    transaction.updateData([
                        "sharesOwned": newShares,
                        "averageCost": avgCost
                    ], forDocument: positionRef)
                }

                return nil
            } catch {
                errorPointer?.pointee = error as NSError
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
