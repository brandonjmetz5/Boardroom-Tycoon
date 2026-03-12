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
        db.collection("marketListings")
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

                completion(.success(listings.sorted { $0.endsAt < $1.endsAt }))
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

                        if buyerCash < buyNowPrice {
                            let error = NSError(
                                domain: "MineMarketService",
                                code: 4005,
                                userInfo: [NSLocalizedDescriptionKey: "Not enough cash to buy this listing."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        // Refund current highest bidder if one exists and it isn't the buyer.
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
                            "cash": buyerCash - buyNowPrice
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
                        "currentBidderID": bidderID
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

                    // Refund previous highest bidder if one exists.
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

                    // Withdraw full new bid amount from new highest bidder.
                    transaction.updateData([
                        "cash": bidderCash - bidAmount
                    ], forDocument: bidderProfileRef)

                    transaction.updateData([
                        "currentBid": bidAmount,
                        "currentBidderID": bidderID
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
}
