//
//  MineMarketService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class MineMarketService {
    private let db = Firestore.firestore()

    func fetchActiveMineListings(completion: @escaping (Result<[MineMarketListing], Error>) -> Void) {
        settleExpiredMineListings { settlementResult in
            switch settlementResult {
            case .failure(let error):
                completion(.failure(error))

            case .success:
                self.db.collection("marketListings")
                    .whereField("listingType", isEqualTo: "mine")
                    .whereField("status", isEqualTo: "active")
                    .getDocuments { snapshot, error in
                        if let error = error {
                            completion(.failure(error))
                            return
                        }

                        guard let documents = snapshot?.documents else {
                            completion(.success([]))
                            return
                        }

                        let listings: [MineMarketListing] = documents.compactMap { document in
                            let data = document.data()

                            guard
                                let id = data["id"] as? String,
                                let sellerID = data["sellerID"] as? String,
                                let buildingID = data["buildingID"] as? String,
                                let resourceTypeRawValue = data["resourceType"] as? String,
                                let resourceType = ResourceType(rawValue: resourceTypeRawValue),
                                let level = data["level"] as? Int,
                                let abundance = data["abundance"] as? Int,
                                let stability = data["stability"] as? Int,
                                let buyNowPrice = data["buyNowPrice"] as? Double,
                                let startingBid = data["startingBid"] as? Double,
                                let currentBid = data["currentBid"] as? Double,
                                let createdAtTimestamp = data["createdAt"] as? Timestamp,
                                let endsAtTimestamp = data["endsAt"] as? Timestamp,
                                let status = data["status"] as? String
                            else {
                                return nil
                            }

                            let currentBidderID = data["currentBidderID"] as? String

                            return MineMarketListing(
                                id: id,
                                sellerID: sellerID,
                                buildingID: buildingID,
                                resourceType: resourceType,
                                level: level,
                                abundance: abundance,
                                stability: stability,
                                buyNowPrice: buyNowPrice,
                                startingBid: startingBid,
                                currentBid: currentBid,
                                currentBidderID: currentBidderID,
                                createdAt: createdAtTimestamp.dateValue(),
                                endsAt: endsAtTimestamp.dateValue(),
                                status: status
                            )
                        }
                        .filter { $0.endsAt > Date() }
                        .sorted { $0.endsAt < $1.endsAt }

                        completion(.success(listings))
                    }
            }
        }
    }

    func listOwnedMineOnMarket(for userID: String, building: Building, buyNowPrice: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(building.id)
        let listingRef = db.collection("marketListings").document("mine-listing-\(UUID().uuidString)")

        db.runTransaction({ transaction, errorPointer in
            do {
                let buildingSnapshot = try transaction.getDocument(buildingRef)

                guard
                    let buildingData = buildingSnapshot.data(),
                    let resourceTypeRawValue = buildingData["resourceType"] as? String,
                    let resourceType = ResourceType(rawValue: resourceTypeRawValue),
                    let level = buildingData["level"] as? Int,
                    let abundance = buildingData["abundance"] as? Int,
                    let stability = buildingData["stability"] as? Int
                else {
                    let error = NSError(
                        domain: "MineMarketService",
                        code: 4030,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid owned mine data."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let isStarterMine = buildingData["isStarterMine"] as? Bool ?? false
                let isListedOnMarket = buildingData["isListedOnMarket"] as? Bool ?? false
                let isProducing = buildingData["isProducing"] as? Bool ?? false

                if isStarterMine {
                    let error = NSError(
                        domain: "MineMarketService",
                        code: 4031,
                        userInfo: [NSLocalizedDescriptionKey: "Starter mine cannot be listed on the market."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if isListedOnMarket {
                    let error = NSError(
                        domain: "MineMarketService",
                        code: 4032,
                        userInfo: [NSLocalizedDescriptionKey: "This mine is already listed on the market."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if isProducing {
                    let error = NSError(
                        domain: "MineMarketService",
                        code: 4033,
                        userInfo: [NSLocalizedDescriptionKey: "Stop production before listing this mine."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if buyNowPrice <= 0 {
                    let error = NSError(
                        domain: "MineMarketService",
                        code: 4034,
                        userInfo: [NSLocalizedDescriptionKey: "Buy now price must be greater than zero."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let startingBid = self.startingBid(for: resourceType, level: level, abundance: abundance, stability: stability)
                let createdAt = Date()
                let endsAt = createdAt.addingTimeInterval(60 * 60 * 24)

                let listingData: [String: Any] = [
                    "id": listingRef.documentID,
                    "listingType": "mine",
                    "sellerID": userID,
                    "buildingID": building.id,
                    "resourceType": resourceType.rawValue,
                    "level": level,
                    "abundance": abundance,
                    "stability": stability,
                    "buyNowPrice": buyNowPrice,
                    "startingBid": startingBid,
                    "currentBid": startingBid,
                    "createdAt": Timestamp(date: createdAt),
                    "endsAt": Timestamp(date: endsAt),
                    "status": "active"
                ]

                transaction.setData(listingData, forDocument: listingRef)
                transaction.updateData([
                    "isListedOnMarket": true,
                    "marketListingID": listingRef.documentID
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

    func buyNowMineListing(for buyerID: String, listing: MineMarketListing, completion: @escaping (Result<Void, Error>) -> Void) {
        let buyerProfileRef = db.collection("playerProfiles").document(buyerID)
        let sellerProfileRef = db.collection("playerProfiles").document(listing.sellerID)

        let buyerBuildingsRef = buyerProfileRef.collection("buildings")
        let buyerJobsRef = buyerProfileRef.collection("prospectingJobs")

        let sellerBuildingRef = sellerProfileRef.collection("buildings").document(listing.buildingID)
        let buyerBuildingRef = buyerBuildingsRef.document(listing.buildingID)
        let listingRef = db.collection("marketListings").document(listing.id)

        buyerBuildingsRef.getDocuments { buyerBuildingsSnapshot, buildingsError in
            if let buildingsError = buildingsError {
                completion(.failure(buildingsError))
                return
            }

            buyerJobsRef.getDocuments { buyerJobsSnapshot, jobsError in
                if let jobsError = jobsError {
                    completion(.failure(jobsError))
                    return
                }

                let buyerBuildingCount = buyerBuildingsSnapshot?.documents.count ?? 0
                let buyerActiveProspectingCount = buyerJobsSnapshot?.documents.filter { doc in
                    let isComplete = doc.data()["isComplete"] as? Bool ?? false
                    return !isComplete
                }.count ?? 0

                self.db.runTransaction({ transaction, errorPointer in
                    do {
                        let buyerProfileSnapshot = try transaction.getDocument(buyerProfileRef)
                        let sellerProfileSnapshot = try transaction.getDocument(sellerProfileRef)
                        let sellerBuildingSnapshot = try transaction.getDocument(sellerBuildingRef)
                        let listingSnapshot = try transaction.getDocument(listingRef)

                        guard
                            let buyerProfileData = buyerProfileSnapshot.data(),
                            let sellerProfileData = sellerProfileSnapshot.data(),
                            let sellerBuildingData = sellerBuildingSnapshot.data(),
                            let listingData = listingSnapshot.data(),
                            let buyerCash = buyerProfileData["cash"] as? Double,
                            let buyerSlotCount = buyerProfileData["buildingSlotCount"] as? Int,
                            let sellerCash = sellerProfileData["cash"] as? Double,
                            let status = listingData["status"] as? String,
                            let buyNowPrice = listingData["buyNowPrice"] as? Double
                        else {
                            let error = NSError(
                                domain: "MineMarketService",
                                code: 4001,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid marketplace data."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        let currentBid = listingData["currentBid"] as? Double ?? 0
                        let currentBidderID = listingData["currentBidderID"] as? String

                        if buyerID == listing.sellerID {
                            let error = NSError(
                                domain: "MineMarketService",
                                code: 4002,
                                userInfo: [NSLocalizedDescriptionKey: "You cannot buy your own listing."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        if status != "active" {
                            let error = NSError(
                                domain: "MineMarketService",
                                code: 4003,
                                userInfo: [NSLocalizedDescriptionKey: "This listing is no longer active."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        let usedSlots = buyerBuildingCount + buyerActiveProspectingCount
                        if usedSlots >= buyerSlotCount {
                            let error = NSError(
                                domain: "MineMarketService",
                                code: 4004,
                                userInfo: [NSLocalizedDescriptionKey: "You do not have an available building slot."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        let buyerFinalCash: Double

                        if currentBidderID == buyerID {
                            let additionalAmountNeeded = buyNowPrice - currentBid

                            if buyerCash < additionalAmountNeeded {
                                let error = NSError(
                                    domain: "MineMarketService",
                                    code: 4007,
                                    userInfo: [NSLocalizedDescriptionKey: "Not enough cash to complete buy now from your current bid position."]
                                )
                                errorPointer?.pointee = error
                                return nil
                            }

                            buyerFinalCash = buyerCash - additionalAmountNeeded
                        } else {
                            if buyerCash < buyNowPrice {
                                let error = NSError(
                                    domain: "MineMarketService",
                                    code: 4005,
                                    userInfo: [NSLocalizedDescriptionKey: "Not enough cash to buy this listing."]
                                )
                                errorPointer?.pointee = error
                                return nil
                            }

                            buyerFinalCash = buyerCash - buyNowPrice
                        }

                        if let currentBidderID, !currentBidderID.isEmpty, currentBidderID != buyerID {
                            let currentBidderProfileRef = self.db.collection("playerProfiles").document(currentBidderID)
                            let currentBidderSnapshot = try transaction.getDocument(currentBidderProfileRef)

                            guard let currentBidderData = currentBidderSnapshot.data(),
                                  let currentBidderCash = currentBidderData["cash"] as? Double else {
                                let error = NSError(
                                    domain: "MineMarketService",
                                    code: 4006,
                                    userInfo: [NSLocalizedDescriptionKey: "Invalid highest bidder data."]
                                )
                                errorPointer?.pointee = error
                                return nil
                            }

                            transaction.updateData([
                                "cash": currentBidderCash + currentBid
                            ], forDocument: currentBidderProfileRef)
                        }

                        var transferredBuildingData = sellerBuildingData
                        transferredBuildingData["isListedOnMarket"] = false
                        transferredBuildingData["marketListingID"] = NSNull()

                        transaction.setData(transferredBuildingData, forDocument: buyerBuildingRef)
                        transaction.deleteDocument(sellerBuildingRef)

                        transaction.updateData([
                            "cash": buyerFinalCash
                        ], forDocument: buyerProfileRef)

                        transaction.updateData([
                            "cash": sellerCash + buyNowPrice
                        ], forDocument: sellerProfileRef)

                        transaction.updateData([
                            "status": "sold"
                        ], forDocument: listingRef)

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
    }

    func placeBid(for bidderID: String, listing: MineMarketListing, bidAmount: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        let listingRef = db.collection("marketListings").document(listing.id)
        let bidderProfileRef = db.collection("playerProfiles").document(bidderID)

        db.runTransaction({ transaction, errorPointer in
            do {
                let listingSnapshot = try transaction.getDocument(listingRef)
                let bidderProfileSnapshot = try transaction.getDocument(bidderProfileRef)

                guard
                    let listingData = listingSnapshot.data(),
                    let bidderProfileData = bidderProfileSnapshot.data(),
                    let status = listingData["status"] as? String,
                    let currentBid = listingData["currentBid"] as? Double,
                    let buyNowPrice = listingData["buyNowPrice"] as? Double,
                    let endsAtTimestamp = listingData["endsAt"] as? Timestamp,
                    let sellerID = listingData["sellerID"] as? String,
                    let bidderCash = bidderProfileData["cash"] as? Double
                else {
                    let error = NSError(
                        domain: "MineMarketService",
                        code: 4010,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid listing data."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let currentBidderID = listingData["currentBidderID"] as? String

                if bidderID == sellerID {
                    let error = NSError(
                        domain: "MineMarketService",
                        code: 4011,
                        userInfo: [NSLocalizedDescriptionKey: "You cannot bid on your own listing."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if status != "active" {
                    let error = NSError(
                        domain: "MineMarketService",
                        code: 4012,
                        userInfo: [NSLocalizedDescriptionKey: "This listing is no longer active."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if endsAtTimestamp.dateValue() <= Date() {
                    let error = NSError(
                        domain: "MineMarketService",
                        code: 4013,
                        userInfo: [NSLocalizedDescriptionKey: "This auction has already ended."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let currentEndDate = endsAtTimestamp.dateValue()
                let secondsRemaining = currentEndDate.timeIntervalSince(Date())

                var updatedEndDate = currentEndDate
                if secondsRemaining < 30 {
                    updatedEndDate = currentEndDate.addingTimeInterval(10)
                }

                if bidAmount <= currentBid {
                    let error = NSError(
                        domain: "MineMarketService",
                        code: 4014,
                        userInfo: [NSLocalizedDescriptionKey: "Your bid must be higher than the current bid."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if bidAmount >= buyNowPrice {
                    let error = NSError(
                        domain: "MineMarketService",
                        code: 4015,
                        userInfo: [NSLocalizedDescriptionKey: "Your bid must be below the buy now price."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if currentBidderID == bidderID {
                    let additionalAmountNeeded = bidAmount - currentBid

                    if bidderCash < additionalAmountNeeded {
                        let error = NSError(
                            domain: "MineMarketService",
                            code: 4016,
                            userInfo: [NSLocalizedDescriptionKey: "Not enough cash to raise your bid."]
                        )
                        errorPointer?.pointee = error
                        return nil
                    }

                    transaction.updateData([
                        "cash": bidderCash - additionalAmountNeeded
                    ], forDocument: bidderProfileRef)

                    transaction.updateData([
                        "currentBid": bidAmount,
                        "currentBidderID": bidderID,
                        "endsAt": Timestamp(date: updatedEndDate)
                    ], forDocument: listingRef)
                } else {
                    if bidderCash < bidAmount {
                        let error = NSError(
                            domain: "MineMarketService",
                            code: 4017,
                            userInfo: [NSLocalizedDescriptionKey: "Not enough cash to place this bid."]
                        )
                        errorPointer?.pointee = error
                        return nil
                    }

                    if let currentBidderID, !currentBidderID.isEmpty {
                        let previousBidderProfileRef = self.db.collection("playerProfiles").document(currentBidderID)
                        let previousBidderSnapshot = try transaction.getDocument(previousBidderProfileRef)

                        guard let previousBidderData = previousBidderSnapshot.data(),
                              let previousBidderCash = previousBidderData["cash"] as? Double else {
                            let error = NSError(
                                domain: "MineMarketService",
                                code: 4018,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid previous bidder data."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        transaction.updateData([
                            "cash": previousBidderCash + currentBid
                        ], forDocument: previousBidderProfileRef)
                    }

                    transaction.updateData([
                        "cash": bidderCash - bidAmount
                    ], forDocument: bidderProfileRef)

                    transaction.updateData([
                        "currentBid": bidAmount,
                        "currentBidderID": bidderID,
                        "endsAt": Timestamp(date: updatedEndDate)
                    ], forDocument: listingRef)
                }

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

    func settleExpiredMineListings(completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("marketListings")
            .whereField("listingType", isEqualTo: "mine")
            .whereField("status", isEqualTo: "active")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success(()))
                    return
                }

                let expiredDocuments = documents.filter { document in
                    guard let endsAtTimestamp = document.data()["endsAt"] as? Timestamp else { return false }
                    return endsAtTimestamp.dateValue() <= Date()
                }

                self.settleExpiredDocuments(expiredDocuments, index: 0, completion: completion)
            }
    }

    private func settleExpiredDocuments(_ documents: [QueryDocumentSnapshot], index: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        if index >= documents.count {
            completion(.success(()))
            return
        }

        let document = documents[index]
        settleExpiredDocument(document) { result in
            switch result {
            case .success:
                self.settleExpiredDocuments(documents, index: index + 1, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func settleExpiredDocument(_ document: QueryDocumentSnapshot, completion: @escaping (Result<Void, Error>) -> Void) {
        let data = document.data()
        let listingRef = document.reference

        guard
            data["sellerID"] as? String != nil,
            data["buildingID"] as? String != nil,
            data["currentBid"] as? Double != nil,
            data["currentBidderID"] as? String != nil
        else {
            self.db.runTransaction({ transaction, errorPointer in
                do {
                    let listingSnapshot = try transaction.getDocument(listingRef)

                    guard let listingData = listingSnapshot.data(),
                          let sellerID = listingData["sellerID"] as? String,
                          let buildingID = listingData["buildingID"] as? String,
                          let status = listingData["status"] as? String
                    else {
                        let error = NSError(
                            domain: "MineMarketService",
                            code: 4020,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid expired listing data."]
                        )
                        errorPointer?.pointee = error
                        return nil
                    }

                    if status != "active" {
                        return nil
                    }

                    let sellerBuildingRef = self.db.collection("playerProfiles")
                        .document(sellerID)
                        .collection("buildings")
                        .document(buildingID)

                    transaction.updateData([
                        "status": "expired"
                    ], forDocument: listingRef)

                    transaction.updateData([
                        "isListedOnMarket": false,
                        "marketListingID": NSNull()
                    ], forDocument: sellerBuildingRef)

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
            return
        }

        self.db.runTransaction({ transaction, errorPointer in
            do {
                let listingSnapshot = try transaction.getDocument(listingRef)

                guard
                    let listingData = listingSnapshot.data(),
                    let sellerID = listingData["sellerID"] as? String,
                    let buildingID = listingData["buildingID"] as? String,
                    let status = listingData["status"] as? String,
                    let currentBid = listingData["currentBid"] as? Double
                else {
                    let error = NSError(
                        domain: "MineMarketService",
                        code: 4021,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid expired listing data."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if status != "active" {
                    return nil
                }

                let currentBidderID = listingData["currentBidderID"] as? String

                let sellerProfileRef = self.db.collection("playerProfiles").document(sellerID)
                let sellerBuildingRef = sellerProfileRef.collection("buildings").document(buildingID)

                if let currentBidderID, !currentBidderID.isEmpty {
                    let bidderProfileRef = self.db.collection("playerProfiles").document(currentBidderID)
                    let bidderBuildingRef = bidderProfileRef.collection("buildings").document(buildingID)

                    let sellerProfileSnapshot = try transaction.getDocument(sellerProfileRef)
                    let sellerBuildingSnapshot = try transaction.getDocument(sellerBuildingRef)

                    guard
                        let sellerProfileData = sellerProfileSnapshot.data(),
                        let sellerCash = sellerProfileData["cash"] as? Double,
                        let sellerBuildingData = sellerBuildingSnapshot.data()
                    else {
                        let error = NSError(
                            domain: "MineMarketService",
                            code: 4022,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid seller data during settlement."]
                        )
                        errorPointer?.pointee = error
                        return nil
                    }

                    var transferredBuildingData = sellerBuildingData
                    transferredBuildingData["isListedOnMarket"] = false
                    transferredBuildingData["marketListingID"] = NSNull()

                    transaction.setData(transferredBuildingData, forDocument: bidderBuildingRef)
                    transaction.deleteDocument(sellerBuildingRef)

                    transaction.updateData([
                        "cash": sellerCash + currentBid
                    ], forDocument: sellerProfileRef)

                    transaction.updateData([
                        "status": "sold"
                    ], forDocument: listingRef)
                } else {
                    transaction.updateData([
                        "status": "expired"
                    ], forDocument: listingRef)

                    transaction.updateData([
                        "isListedOnMarket": false,
                        "marketListingID": NSNull()
                    ], forDocument: sellerBuildingRef)
                }

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

    private func startingBid(for resourceType: ResourceType, level: Int, abundance: Int, stability: Int) -> Double {
        let baseValue: Double

        switch resourceType {
        case .gold:
            baseValue = 800
        case .silver:
            baseValue = 700
        case .diamond:
            baseValue = 1200
        case .oil:
            baseValue = 900
        case .coal:
            baseValue = 650
        case .iron:
            baseValue = 750
        default:
            baseValue = 700
        }

        let statBonus = Double((abundance - 50) + (stability - 50)) * 12.0
        let levelBonus = Double(level - 1) * 150.0

        return max(100, baseValue + statBonus + levelBonus)
    }
}
