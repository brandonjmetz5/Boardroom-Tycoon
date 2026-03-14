//
//  ProductionService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class ProductionService {
    private let db = Firestore.firestore()

    /// Fuel cells consumed per production cycle (design: 1 per cycle).
    private let fuelCostPerCycle: Double = 1

    /// Inventory document ID for fuel (matches starter inventory and Item catalog).
    private let fuelInventoryDocID = "fuel-cell"

    func startProduction(for userID: String, buildingID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(buildingID)
        let fuelRef = profileRef.collection("inventory").document(fuelInventoryDocID)

        db.runTransaction({ transaction, errorPointer in
            do {
                let buildingSnapshot = try transaction.getDocument(buildingRef)
                let fuelSnapshot = try transaction.getDocument(fuelRef)

                guard let data = buildingSnapshot.data() else {
                    errorPointer?.pointee = NSError(
                        domain: "ProductionService",
                        code: 2000,
                        userInfo: [NSLocalizedDescriptionKey: "Building not found."]
                    )
                    return nil
                }

                guard
                    let abundance = data["abundance"] as? Int,
                    let stability = data["stability"] as? Int
                else {
                    errorPointer?.pointee = NSError(
                        domain: "ProductionService",
                        code: 2000,
                        userInfo: [NSLocalizedDescriptionKey: "Missing mine stat data."]
                    )
                    return nil
                }

                let isListedOnMarket = data["isListedOnMarket"] as? Bool ?? false
                if isListedOnMarket {
                    errorPointer?.pointee = NSError(
                        domain: "ProductionService",
                        code: 2004,
                        userInfo: [NSLocalizedDescriptionKey: "This mine is listed on the market and cannot produce right now."]
                    )
                    return nil
                }

                let fuelQuantity = fuelSnapshot.data()?["quantity"] as? Double ?? 0
                if fuelQuantity < self.fuelCostPerCycle {
                    errorPointer?.pointee = NSError(
                        domain: "ProductionService",
                        code: 2006,
                        userInfo: [NSLocalizedDescriptionKey: "Not enough fuel. Each production cycle costs 1 Fuel Cell."]
                    )
                    return nil
                }

                let startedAt = Date()
                #if DEBUG
                let cycleSeconds: TimeInterval = 10
                #else
                let cycleSeconds: TimeInterval = 60 * 60
                #endif
                let endsAt = startedAt.addingTimeInterval(cycleSeconds)
                let pendingOutputQuantity = Double(self.generateMineOutput(abundance: abundance, stability: stability))

                transaction.updateData([
                    "isProducing": true,
                    "productionStartedAt": Timestamp(date: startedAt),
                    "productionEndsAt": Timestamp(date: endsAt),
                    "pendingOutputQuantity": pendingOutputQuantity
                ], forDocument: buildingRef)

                let newFuelQuantity = fuelQuantity - self.fuelCostPerCycle
                let fuelData: [String: Any] = fuelSnapshot.data() ?? [
                    "id": self.fuelInventoryDocID,
                    "name": "Fuel Cell",
                    "category": "Fuel",
                    "isFractional": false
                ]
                var updatedFuel = fuelData
                updatedFuel["quantity"] = newFuelQuantity
                transaction.setData(updatedFuel, forDocument: fuelRef)

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

    func collectProduction(for userID: String, buildingID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(buildingID)

        db.runTransaction({ transaction, errorPointer in
            do {
                let profileSnapshot = try transaction.getDocument(profileRef)
                let buildingSnapshot = try transaction.getDocument(buildingRef)

                guard
                    let buildingData = buildingSnapshot.data(),
                    let profileData = profileSnapshot.data(),
                    let pendingOutputQuantity = buildingData["pendingOutputQuantity"] as? Double,
                    let isProducing = buildingData["isProducing"] as? Bool,
                    let productionEndsAtTimestamp = buildingData["productionEndsAt"] as? Timestamp,
                    let currentXP = profileData["xp"] as? Int,
                    let resourceTypeRawValue = buildingData["resourceType"] as? String,
                    let resourceType = ResourceType(rawValue: resourceTypeRawValue)
                else {
                    let error = NSError(
                        domain: "ProductionService",
                        code: 2001,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid building production data."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let isListedOnMarket = buildingData["isListedOnMarket"] as? Bool ?? false
                if isListedOnMarket {
                    let error = NSError(
                        domain: "ProductionService",
                        code: 2005,
                        userInfo: [NSLocalizedDescriptionKey: "This mine is listed on the market and cannot collect production."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if !isProducing {
                    let error = NSError(
                        domain: "ProductionService",
                        code: 2002,
                        userInfo: [NSLocalizedDescriptionKey: "This building is not producing."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if productionEndsAtTimestamp.dateValue() > Date() {
                    let error = NSError(
                        domain: "ProductionService",
                        code: 2003,
                        userInfo: [NSLocalizedDescriptionKey: "Production is not finished yet."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let inventoryDocID = self.inventoryDocumentID(for: resourceType)
                let inventoryName = self.inventoryDisplayName(for: resourceType)
                let inventoryRef = profileRef.collection("inventory").document(inventoryDocID)
                let inventorySnapshot = try transaction.getDocument(inventoryRef)

                let currentQuantity = inventorySnapshot.data()?["quantity"] as? Double ?? 0.0
                let xpReward = 10
                let updatedXP = currentXP + xpReward
                let updatedLevel = self.levelForTotalXP(updatedXP)
                let updatedBuildingSlotCount = self.buildingSlotCount(for: updatedLevel)

                let inventoryData: [String: Any] = [
                    "id": inventoryDocID,
                    "name": inventoryName,
                    "category": "Raw Material",
                    "isFractional": false,
                    "quantity": currentQuantity + pendingOutputQuantity
                ]

                transaction.setData(inventoryData, forDocument: inventoryRef)
                transaction.updateData([
                    "isProducing": false,
                    "productionStartedAt": NSNull(),
                    "productionEndsAt": NSNull(),
                    "pendingOutputQuantity": 0.0
                ], forDocument: buildingRef)

                transaction.updateData([
                    "xp": updatedXP,
                    "level": updatedLevel,
                    "buildingSlotCount": updatedBuildingSlotCount
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

    private func generateMineOutput(abundance: Int, stability: Int) -> Int {
        let maxOutput = max(1, abundance - 40)

        let normalizedStability = Double(stability - 50) / 50.0
        let stabilityMultiplier = 0.5 + (normalizedStability * 0.4)

        let rawMinOutput = Double(maxOutput) * stabilityMultiplier
        let minOutput = max(1, Int(rawMinOutput.rounded(.down)))

        return Int.random(in: minOutput...maxOutput)
    }

    private func inventoryDocumentID(for resourceType: ResourceType) -> String {
        switch resourceType {
        case .gold:
            return "raw-gold"
        case .silver:
            return "raw-silver"
        case .diamond:
            return "raw-diamonds"
        case .oil:
            return "crude-oil"
        case .coal:
            return "raw-coal"
        case .iron:
            return "raw-iron"
        default:
            return "raw-material"
        }
    }

    private func inventoryDisplayName(for resourceType: ResourceType) -> String {
        switch resourceType {
        case .gold:
            return "Raw Gold"
        case .silver:
            return "Raw Silver"
        case .diamond:
            return "Raw Diamonds"
        case .oil:
            return "Crude Oil"
        case .coal:
            return "Raw Coal"
        case .iron:
            return "Raw Iron"
        default:
            return resourceType.rawValue
        }
    }

    private func xpNeededForNextLevel(from level: Int) -> Int {
        100 + ((level - 1) * 25)
    }

    private func levelForTotalXP(_ totalXP: Int) -> Int {
        var level = 1
        var xpRemaining = totalXP

        while xpRemaining >= xpNeededForNextLevel(from: level) {
            xpRemaining -= xpNeededForNextLevel(from: level)
            level += 1
        }

        return level
    }

    private func buildingSlotCount(for level: Int) -> Int {
        2 + ((level / 10) * 2)
    }
}
