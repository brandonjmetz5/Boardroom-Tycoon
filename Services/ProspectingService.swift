//
//  ProspectingService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class ProspectingService {
    private let db = Firestore.firestore()

    func fetchProspectingJobs(for userID: String, completion: @escaping (Result<[ProspectingJob], Error>) -> Void) {
        let jobsRef = db.collection("playerProfiles").document(userID).collection("prospectingJobs")

        jobsRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let jobs: [ProspectingJob] = documents.compactMap { document in
                let data = document.data()

                guard
                    let id = data["id"] as? String,
                    let resourceTypeRawValue = data["resourceType"] as? String,
                    let resourceType = ResourceType(rawValue: resourceTypeRawValue),
                    let startedAtTimestamp = data["startedAt"] as? Timestamp,
                    let endsAtTimestamp = data["endsAt"] as? Timestamp,
                    let isComplete = data["isComplete"] as? Bool,
                    let isRevealed = data["isRevealed"] as? Bool
                else {
                    return nil
                }

                let revealedAbundance = data["revealedAbundance"] as? Int
                let revealedStability = data["revealedStability"] as? Int

                return ProspectingJob(
                    id: id,
                    resourceType: resourceType,
                    startedAt: startedAtTimestamp.dateValue(),
                    endsAt: endsAtTimestamp.dateValue(),
                    isComplete: isComplete,
                    isRevealed: isRevealed,
                    revealedAbundance: revealedAbundance,
                    revealedStability: revealedStability
                )
            }

            completion(.success(jobs))
        }
    }

    func startProspecting(for userID: String, resourceType: ResourceType, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingsRef = profileRef.collection("buildings")
        let jobsRef = profileRef.collection("prospectingJobs")

        let prospectingCost = 750.0

        buildingsRef.getDocuments { buildingSnapshot, buildingError in
            if let buildingError = buildingError {
                completion(.failure(buildingError))
                return
            }

            jobsRef.getDocuments { jobSnapshot, jobError in
                if let jobError = jobError {
                    completion(.failure(jobError))
                    return
                }

                let currentBuildingCount = buildingSnapshot?.documents.count ?? 0

                let activeJobCount = jobSnapshot?.documents.filter { document in
                    let data = document.data()
                    let isComplete = data["isComplete"] as? Bool ?? false
                    return !isComplete
                }.count ?? 0

                self.db.runTransaction({ transaction, errorPointer in
                    do {
                        let profileSnapshot = try transaction.getDocument(profileRef)

                        guard
                            let profileData = profileSnapshot.data(),
                            let currentCash = profileData["cash"] as? Double,
                            let buildingSlotCount = profileData["buildingSlotCount"] as? Int
                        else {
                            let error = NSError(
                                domain: "ProspectingService",
                                code: 3001,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid player profile data."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        if activeJobCount > 0 {
                            let error = NSError(
                                domain: "ProspectingService",
                                code: 3002,
                                userInfo: [NSLocalizedDescriptionKey: "Only one active prospecting job is allowed."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        let usedSlots = currentBuildingCount + activeJobCount
                        if usedSlots >= buildingSlotCount {
                            let error = NSError(
                                domain: "ProspectingService",
                                code: 3003,
                                userInfo: [NSLocalizedDescriptionKey: "No available building slots for prospecting."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        if currentCash < prospectingCost {
                            let error = NSError(
                                domain: "ProspectingService",
                                code: 3004,
                                userInfo: [NSLocalizedDescriptionKey: "Not enough cash to start prospecting."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        let jobRef = jobsRef.document("prospecting-\(UUID().uuidString)")
                        let startedAt = Date()
                        let endsAt = startedAt.addingTimeInterval(10) // temporary 10 seconds for testing
                        // let endsAt = startedAt.addingTimeInterval(60 * 60 * 4)

                        let jobData: [String: Any] = [
                            "id": jobRef.documentID,
                            "resourceType": resourceType.rawValue,
                            "startedAt": Timestamp(date: startedAt),
                            "endsAt": Timestamp(date: endsAt),
                            "isComplete": false,
                            "isRevealed": false
                        ]

                        transaction.setData(jobData, forDocument: jobRef)
                        transaction.updateData([
                            "cash": currentCash - prospectingCost
                        ], forDocument: profileRef)

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

    func revealProspectingJob(for userID: String, jobID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let jobRef = db.collection("playerProfiles")
            .document(userID)
            .collection("prospectingJobs")
            .document(jobID)

        db.runTransaction({ transaction, errorPointer in
            do {
                let jobSnapshot = try transaction.getDocument(jobRef)

                guard
                    let jobData = jobSnapshot.data(),
                    let endsAtTimestamp = jobData["endsAt"] as? Timestamp,
                    let isComplete = jobData["isComplete"] as? Bool,
                    let isRevealed = jobData["isRevealed"] as? Bool
                else {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3010,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid prospecting job data."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if isComplete {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3011,
                        userInfo: [NSLocalizedDescriptionKey: "This prospecting job is already completed."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if isRevealed {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3012,
                        userInfo: [NSLocalizedDescriptionKey: "This prospecting job has already been revealed."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if endsAtTimestamp.dateValue() > Date() {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3013,
                        userInfo: [NSLocalizedDescriptionKey: "Prospecting is not finished yet."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let abundance = Int.random(in: 50...100)
                let stability = Int.random(in: 50...100)

                transaction.updateData([
                    "isRevealed": true,
                    "revealedAbundance": abundance,
                    "revealedStability": stability
                ], forDocument: jobRef)

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

    func keepProspectedMine(for userID: String, job: ProspectingJob, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let jobsRef = profileRef.collection("prospectingJobs")
        let jobRef = jobsRef.document(job.id)
        let buildingsRef = profileRef.collection("buildings")
        let newBuildingRef = buildingsRef.document("building-\(UUID().uuidString)")

        db.runTransaction({ transaction, errorPointer in
            do {
                let jobSnapshot = try transaction.getDocument(jobRef)

                guard
                    let jobData = jobSnapshot.data(),
                    let resourceTypeRawValue = jobData["resourceType"] as? String,
                    let resourceType = ResourceType(rawValue: resourceTypeRawValue),
                    let isComplete = jobData["isComplete"] as? Bool,
                    let isRevealed = jobData["isRevealed"] as? Bool,
                    let abundance = jobData["revealedAbundance"] as? Int,
                    let stability = jobData["revealedStability"] as? Int
                else {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3020,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid revealed prospecting data."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if isComplete {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3021,
                        userInfo: [NSLocalizedDescriptionKey: "This prospecting job is already completed."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if !isRevealed {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3022,
                        userInfo: [NSLocalizedDescriptionKey: "Reveal the prospecting result first."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let buildingName = self.buildingName(for: resourceType)

                let buildingData: [String: Any] = [
                    "id": newBuildingRef.documentID,
                    "name": buildingName,
                    "type": self.buildingType(for: resourceType).rawValue,
                    "level": 1,
                    "capacity": 1,
                    "resourceType": resourceType.rawValue,
                    "abundance": abundance,
                    "stability": stability,
                    "isStarterMine": false,
                    "isListedOnMarket": false,
                    "marketListingID": NSNull()
                ]

                transaction.setData(buildingData, forDocument: newBuildingRef)
                transaction.updateData([
                    "isComplete": true
                ], forDocument: jobRef)

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
    
    func listProspectedMine(for userID: String, job: ProspectingJob, buyNowPrice: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let jobRef = profileRef.collection("prospectingJobs").document(job.id)
        let buildingsRef = profileRef.collection("buildings")
        let newBuildingRef = buildingsRef.document("building-\(UUID().uuidString)")
        let listingRef = db.collection("marketListings").document("mine-listing-\(UUID().uuidString)")

        db.runTransaction({ transaction, errorPointer in
            do {
                let jobSnapshot = try transaction.getDocument(jobRef)

                guard
                    let jobData = jobSnapshot.data(),
                    let resourceTypeRawValue = jobData["resourceType"] as? String,
                    let resourceType = ResourceType(rawValue: resourceTypeRawValue),
                    let isComplete = jobData["isComplete"] as? Bool,
                    let isRevealed = jobData["isRevealed"] as? Bool,
                    let abundance = jobData["revealedAbundance"] as? Int,
                    let stability = jobData["revealedStability"] as? Int
                else {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3040,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid revealed prospecting data."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if isComplete {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3041,
                        userInfo: [NSLocalizedDescriptionKey: "This prospecting job is already completed."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if !isRevealed {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3042,
                        userInfo: [NSLocalizedDescriptionKey: "Reveal the prospecting result first."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if buyNowPrice <= 0 {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3043,
                        userInfo: [NSLocalizedDescriptionKey: "Buy now price must be greater than zero."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let buildingName = self.buildingName(for: resourceType)
                let startingBid = self.startingBid(for: resourceType, level: 1, abundance: abundance, stability: stability)
                let createdAt = Date()
                //let endsAt = createdAt.addingTimeInterval(60 * 60 * 24)
                let endsAt = createdAt.addingTimeInterval(60)

                let buildingData: [String: Any] = [
                    "id": newBuildingRef.documentID,
                    "name": buildingName,
                    "type": self.buildingType(for: resourceType).rawValue,
                    "level": 1,
                    "capacity": 1,
                    "resourceType": resourceType.rawValue,
                    "abundance": abundance,
                    "stability": stability,
                    "isStarterMine": false,
                    "isListedOnMarket": true,
                    "marketListingID": listingRef.documentID
                ]

                let listingData: [String: Any] = [
                    "id": listingRef.documentID,
                    "listingType": "mine",
                    "sellerID": userID,
                    "buildingID": newBuildingRef.documentID,
                    "resourceType": resourceType.rawValue,
                    "level": 1,
                    "abundance": abundance,
                    "stability": stability,
                    "buyNowPrice": buyNowPrice,
                    "startingBid": startingBid,
                    "currentBid": startingBid,
                    "createdAt": Timestamp(date: createdAt),
                    "endsAt": Timestamp(date: endsAt),
                    "status": "active"
                ]

                transaction.setData(buildingData, forDocument: newBuildingRef)
                transaction.setData(listingData, forDocument: listingRef)
                transaction.updateData([
                    "isComplete": true
                ], forDocument: jobRef)

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

    func sellProspectedMine(for userID: String, job: ProspectingJob, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let jobRef = profileRef.collection("prospectingJobs").document(job.id)

        let sellRefund = 250.0

        db.runTransaction({ transaction, errorPointer in
            do {
                let profileSnapshot = try transaction.getDocument(profileRef)
                let jobSnapshot = try transaction.getDocument(jobRef)

                guard
                    let profileData = profileSnapshot.data(),
                    let currentCash = profileData["cash"] as? Double,
                    let jobData = jobSnapshot.data(),
                    let isComplete = jobData["isComplete"] as? Bool,
                    let isRevealed = jobData["isRevealed"] as? Bool
                else {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3030,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid sell prospecting data."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if isComplete {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3031,
                        userInfo: [NSLocalizedDescriptionKey: "This prospecting job is already completed."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if !isRevealed {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3032,
                        userInfo: [NSLocalizedDescriptionKey: "Reveal the prospecting result first."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                transaction.updateData([
                    "cash": currentCash + sellRefund
                ], forDocument: profileRef)

                transaction.updateData([
                    "isComplete": true
                ], forDocument: jobRef)

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
    
    func suggestedMarketPricing(for resourceType: ResourceType, level: Int, abundance: Int, stability: Int) -> (startingBid: Double, suggestedBuyNowLow: Double, suggestedBuyNowHigh: Double) {
        let startingBid = self.startingBid(for: resourceType, level: level, abundance: abundance, stability: stability)
        let suggestedBuyNowLow = startingBid * 1.35
        let suggestedBuyNowHigh = startingBid * 1.75

        return (startingBid, suggestedBuyNowLow, suggestedBuyNowHigh)
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

    private func buildingName(for resourceType: ResourceType) -> String {
        switch resourceType {
        case .gold:
            return "Gold Mine"
        case .silver:
            return "Silver Mine"
        case .diamond:
            return "Diamond Mine"
        case .oil:
            return "Oil Rig"
        case .coal:
            return "Coal Mine"
        case .iron:
            return "Iron Mine"
        default:
            return resourceType.rawValue
        }
    }

    private func buildingType(for resourceType: ResourceType) -> BuildingType {
        switch resourceType {
        case .oil:
            return .rig
        case .gold, .silver, .diamond, .coal, .iron:
            return .mine
        default:
            return .mine
        }
    }
}
