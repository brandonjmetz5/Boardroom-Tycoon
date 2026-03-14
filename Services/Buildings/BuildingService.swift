//
//  BuildingService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class BuildingService {
    private let db = Firestore.firestore()

    func fetchBuildings(for userID: String, completion: @escaping (Result<[Building], Error>) -> Void) {
        let buildingsRef = db.collection("playerProfiles").document(userID).collection("buildings")

        buildingsRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let buildings: [Building] = documents.compactMap { document in
                let data = document.data()

                guard
                    let id = data["id"] as? String,
                    let name = data["name"] as? String,
                    let typeRawValue = data["type"] as? String,
                    let type = BuildingType(rawValue: typeRawValue),
                    let level = data["level"] as? Int,
                    let capacity = data["capacity"] as? Int
                else {
                    return nil
                }

                let slotIndex = data["slotIndex"] as? Int ?? Int.max

                let resourceType: ResourceType?
                if let resourceTypeRawValue = data["resourceType"] as? String {
                    resourceType = ResourceType(rawValue: resourceTypeRawValue)
                } else {
                    resourceType = nil
                }

                let abundance = data["abundance"] as? Int
                let stability = data["stability"] as? Int
                let isStarterMine = data["isStarterMine"] as? Bool

                let isProducing = data["isProducing"] as? Bool

                let productionStartedAt: Date?
                if let startedAtTimestamp = data["productionStartedAt"] as? Timestamp {
                    productionStartedAt = startedAtTimestamp.dateValue()
                } else {
                    productionStartedAt = nil
                }

                let productionEndsAt: Date?
                if let endsAtTimestamp = data["productionEndsAt"] as? Timestamp {
                    productionEndsAt = endsAtTimestamp.dateValue()
                } else {
                    productionEndsAt = nil
                }

                let pendingOutputQuantity = data["pendingOutputQuantity"] as? Double

                let isListedOnMarket = data["isListedOnMarket"] as? Bool
                let marketListingID = data["marketListingID"] as? String

                return Building(
                    id: id,
                    name: name,
                    type: type,
                    level: level,
                    capacity: capacity,
                    slotIndex: slotIndex,
                    resourceType: resourceType,
                    abundance: abundance,
                    stability: stability,
                    isStarterMine: isStarterMine,
                    isProducing: isProducing,
                    productionStartedAt: productionStartedAt,
                    productionEndsAt: productionEndsAt,
                    pendingOutputQuantity: pendingOutputQuantity,
                    isListedOnMarket: isListedOnMarket,
                    marketListingID: marketListingID
                )
            }

            completion(.success(buildings.sorted { $0.slotIndex < $1.slotIndex }))
        }
    }

    func purchaseStarterMine(for userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingsRef = profileRef.collection("buildings")
        let starterMineRef = buildingsRef.document("building-starter-gold-mine")

        db.runTransaction({ transaction, errorPointer in
            do {
                let profileSnapshot = try transaction.getDocument(profileRef)
                let starterMineSnapshot = try transaction.getDocument(starterMineRef)

                guard
                    var cash = profileSnapshot.data()?["cash"] as? Double,
                    let starterMineClaimed = profileSnapshot.data()?["starterMineClaimed"] as? Bool
                else {
                    let error = NSError(
                        domain: "BuildingService",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid player profile data."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let starterMineCost = 500.0

                if starterMineClaimed {
                    let error = NSError(
                        domain: "BuildingService",
                        code: 1002,
                        userInfo: [NSLocalizedDescriptionKey: "Starter mine has already been claimed."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if starterMineSnapshot.exists {
                    let error = NSError(
                        domain: "BuildingService",
                        code: 1005,
                        userInfo: [NSLocalizedDescriptionKey: "Starter mine already exists."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if cash < starterMineCost {
                    let error = NSError(
                        domain: "BuildingService",
                        code: 1003,
                        userInfo: [NSLocalizedDescriptionKey: "Not enough cash to purchase the starter mine."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                cash -= starterMineCost

                let buildingData: [String: Any] = [
                    "id": "building-starter-gold-mine",
                    "name": "Starter Gold Mine",
                    "type": "Mine",
                    "level": 1,
                    "capacity": 1,
                    "slotIndex": 0,
                    "resourceType": "Gold",
                    "abundance": 50,
                    "stability": 55,
                    "isStarterMine": true,
                    "isListedOnMarket": false,
                    "marketListingID": NSNull()
                ]

                transaction.setData(buildingData, forDocument: starterMineRef)
                transaction.updateData([
                    "cash": cash,
                    "starterMineClaimed": true
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

    func purchaseBuilding(
        for userID: String,
        purchasableBuilding: PurchasableBuilding,
        slotIndex: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingsRef = profileRef.collection("buildings")
        let jobsRef = profileRef.collection("prospectingJobs")

        buildingsRef.getDocuments { buildingSnapshot, fetchError in
            if let fetchError = fetchError {
                completion(.failure(fetchError))
                return
            }

            jobsRef.getDocuments { jobSnapshot, jobError in
                if let jobError = jobError {
                    completion(.failure(jobError))
                    return
                }

                let currentBuildingCount = buildingSnapshot?.documents.count ?? 0
                let activeJobCount = jobSnapshot?.documents.filter {
                    let isComplete = $0.data()["isComplete"] as? Bool ?? false
                    return !isComplete
                }.count ?? 0

                let newBuildingRef = buildingsRef.document("building-\(UUID().uuidString)")

                self.db.runTransaction({ transaction, errorPointer in
                    do {
                        let profileSnapshot = try transaction.getDocument(profileRef)

                        guard
                            let profileData = profileSnapshot.data(),
                            let currentCash = profileData["cash"] as? Double,
                            let buildingSlotCount = profileData["buildingSlotCount"] as? Int
                        else {
                            let error = NSError(
                                domain: "BuildingService",
                                code: 1101,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid player profile data."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        let usedSlots = currentBuildingCount + activeJobCount
                        if usedSlots >= buildingSlotCount {
                            let error = NSError(
                                domain: "BuildingService",
                                code: 1102,
                                userInfo: [NSLocalizedDescriptionKey: "No available building slots."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        if currentCash < purchasableBuilding.cost {
                            let error = NSError(
                                domain: "BuildingService",
                                code: 1103,
                                userInfo: [NSLocalizedDescriptionKey: "Not enough cash to purchase this building."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        let updatedCash = currentCash - purchasableBuilding.cost

                        let buildingData: [String: Any] = [
                            "id": newBuildingRef.documentID,
                            "name": purchasableBuilding.name,
                            "type": purchasableBuilding.type.rawValue,
                            "level": 1,
                            "capacity": 1,
                            "slotIndex": slotIndex
                        ]

                        transaction.setData(buildingData, forDocument: newBuildingRef)
                        transaction.updateData([
                            "cash": updatedCash
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

    func sellBuildingToSystem(for userID: String, building: Building, sellValue: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(building.id)

        db.runTransaction({ transaction, errorPointer in
            do {
                let profileSnapshot = try transaction.getDocument(profileRef)
                let buildingSnapshot = try transaction.getDocument(buildingRef)

                guard
                    let profileData = profileSnapshot.data(),
                    let currentCash = profileData["cash"] as? Double,
                    let buildingData = buildingSnapshot.data(),
                    let isListedOnMarket = buildingData["isListedOnMarket"] as? Bool
                else {
                    let error = NSError(
                        domain: "BuildingService",
                        code: 1201,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid building or profile data."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if isListedOnMarket {
                    let error = NSError(
                        domain: "BuildingService",
                        code: 1202,
                        userInfo: [NSLocalizedDescriptionKey: "Listed buildings cannot be sold to the system."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if building.id == "building-starter-gold-mine" {
                    let error = NSError(
                        domain: "BuildingService",
                        code: 1203,
                        userInfo: [NSLocalizedDescriptionKey: "Starter mine cannot be sold to the system."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let updatedCash = currentCash + sellValue

                transaction.deleteDocument(buildingRef)
                transaction.updateData([
                    "cash": updatedCash
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
