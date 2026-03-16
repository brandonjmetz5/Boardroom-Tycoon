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

    /// Base fuel cells per extractor cycle (level 1). Level N uses 10 * throughputMultiplier(N), rounded.
    static let baseFuelPerExtractorCycle: Double = 10

    /// Inventory document ID for fuel (matches starter inventory and Item catalog).
    private let fuelInventoryDocID = "fuel-cell"

    func startProduction(for userID: String, buildingID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(buildingID)
        let fuelRef = profileRef.collection("inventory").document(fuelInventoryDocID)

        buildingRef.getDocument { [weak self] buildingSnapshot, buildingError in
            guard let self else { return }
            if let buildingError = buildingError {
                completion(.failure(buildingError))
                return
            }
            guard let buildingData = buildingSnapshot?.data() else {
                completion(.failure(NSError(domain: "ProductionService", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Building not found."])))
                return
            }
            let level = buildingData["level"] as? Int ?? 1
            let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: level)
            let fuelRequired = BuildingLevelCatalog.scaleQuantity(Self.baseFuelPerExtractorCycle, throughputMultiplier: mult)
            let buildingAbundance = buildingData["abundance"] as? Int ?? 50
            let buildingStability = buildingData["stability"] as? Int ?? 50
            let baseOutput = self.generateMineOutput(abundance: buildingAbundance, stability: buildingStability)
            let totalOutput = Int(BuildingLevelCatalog.scaleQuantity(Double(baseOutput), throughputMultiplier: mult))

            self.db.runTransaction({ transaction, errorPointer in
                do {
                    let buildingSnap = try transaction.getDocument(buildingRef)
                    let fuelSnapshot = try transaction.getDocument(fuelRef)

                    guard let data = buildingSnap.data() else {
                        errorPointer?.pointee = NSError(domain: "ProductionService", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Building not found."])
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
                    if fuelQuantity < fuelRequired {
                        errorPointer?.pointee = NSError(
                            domain: "ProductionService",
                            code: 2006,
                            userInfo: [NSLocalizedDescriptionKey: "Not enough fuel. This cycle costs \(Int(fuelRequired)) Fuel Cells."]
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

                    transaction.updateData([
                        "isProducing": true,
                        "productionStartedAt": Timestamp(date: startedAt),
                        "productionEndsAt": Timestamp(date: endsAt),
                        "pendingOutputQuantity": Double(totalOutput)
                    ], forDocument: buildingRef)

                    let newFuelQuantity = fuelQuantity - fuelRequired
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
    }

    func collectProduction(for userID: String, buildingID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(buildingID)

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                let profileSnapshot = try transaction.getDocument(profileRef)
                let buildingSnapshot = try transaction.getDocument(buildingRef)
                guard let buildingData = buildingSnapshot.data(), let profileData = profileSnapshot.data() else {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Invalid building or profile data."])
                    return nil
                }
                let isProducing = buildingData["isProducing"] as? Bool ?? false
                let productionEndsAtTimestamp = buildingData["productionEndsAt"] as? Timestamp
                let isListedOnMarket = buildingData["isListedOnMarket"] as? Bool ?? false
                if isListedOnMarket {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2005, userInfo: [NSLocalizedDescriptionKey: "Listed buildings cannot collect production."])
                    return nil
                }
                if !isProducing {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2002, userInfo: [NSLocalizedDescriptionKey: "This building is not producing."])
                    return nil
                }
                guard let endsAt = productionEndsAtTimestamp?.dateValue(), endsAt <= Date() else {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2003, userInfo: [NSLocalizedDescriptionKey: "Production is not finished yet."])
                    return nil
                }

                let pendingOutputQuantity = buildingData["pendingOutputQuantity"] as? Double ?? 0
                if let resourceTypeRawValue = buildingData["resourceType"] as? String,
                   let resourceType = ResourceType(rawValue: resourceTypeRawValue) {
                    let inventoryDocID = self.inventoryDocumentID(for: resourceType)
                    let inventoryName = self.inventoryDisplayName(for: resourceType)
                    let inventoryRef = profileRef.collection("inventory").document(inventoryDocID)
                    let inventorySnapshot = try transaction.getDocument(inventoryRef)
                    let currentQuantity = inventorySnapshot.data()?["quantity"] as? Double ?? 0.0
                    let currentXP = profileData["xp"] as? Int ?? 0
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
                    transaction.updateData(["xp": updatedXP, "level": updatedLevel, "buildingSlotCount": updatedBuildingSlotCount], forDocument: profileRef)
                } else if let outputItemId = buildingData["pendingOutputItemId"] as? String,
                          let outputItemName = buildingData["pendingOutputItemName"] as? String {
                    let inventoryRef = profileRef.collection("inventory").document(outputItemId)
                    let inventorySnapshot = try transaction.getDocument(inventoryRef)
                    let existingData = inventorySnapshot.data()
                    let currentQuantity = existingData?["quantity"] as? Double ?? 0.0
                    let category = existingData?["category"] as? String ?? "Refined Material"
                    let isFractional = existingData?["isFractional"] as? Bool ?? false
                    let inventoryData: [String: Any] = [
                        "id": outputItemId,
                        "name": outputItemName,
                        "category": category,
                        "isFractional": isFractional,
                        "quantity": currentQuantity + pendingOutputQuantity
                    ]
                    transaction.setData(inventoryData, forDocument: inventoryRef)
                }

                transaction.updateData([
                    "isProducing": false,
                    "productionStartedAt": NSNull(),
                    "productionEndsAt": NSNull(),
                    "pendingOutputQuantity": 0.0,
                    "pendingOutputItemId": NSNull(),
                    "pendingOutputItemName": NSNull()
                ], forDocument: buildingRef)

                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }) { _, error in
            if let error = error { completion(.failure(error)) }
            else { completion(.success(())) }
        }
    }

    /// Start recipe-based production: consume scaled inputs from inventory, set building producing with scaled output (throughput by building level).
    func startRecipeProduction(for userID: String, building: Building, recipe: Recipe, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(building.id)

        guard let firstOutput = recipe.outputItems.first else {
            completion(.failure(NSError(domain: "ProductionService", code: 2010, userInfo: [NSLocalizedDescriptionKey: "Recipe has no output."])))
            return
        }

        let level = building.level
        let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: level)
        let scaledInputs: [(RecipeIngredient, Double)] = recipe.inputItems.map { ing in
            let qty = ing.item.isFractional
                ? BuildingLevelCatalog.scaleQuantityFractional(ing.quantity, throughputMultiplier: mult)
                : BuildingLevelCatalog.scaleQuantity(ing.quantity, throughputMultiplier: mult)
            return (ing, qty)
        }
        let scaledOutputQty = firstOutput.item.isFractional
            ? BuildingLevelCatalog.scaleQuantityFractional(firstOutput.quantity, throughputMultiplier: mult)
            : BuildingLevelCatalog.scaleQuantity(firstOutput.quantity, throughputMultiplier: mult)

        #if DEBUG
        let cycleSeconds: TimeInterval = 10
        #else
        let cycleSeconds = TimeInterval(recipe.cycleTimeInMinutes * 60)
        #endif

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                let buildingSnapshot = try transaction.getDocument(buildingRef)
                guard let buildingData = buildingSnapshot.data() else {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Building not found."])
                    return nil
                }
                if buildingData["isListedOnMarket"] as? Bool == true {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2004, userInfo: [NSLocalizedDescriptionKey: "Building cannot produce while listed."])
                    return nil
                }
                if buildingData["isProducing"] as? Bool == true {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2007, userInfo: [NSLocalizedDescriptionKey: "Already producing."])
                    return nil
                }

                var inventorySnaps: [(DocumentReference, DocumentSnapshot, Double)] = []
                for (ing, needQty) in scaledInputs {
                    let invRef = profileRef.collection("inventory").document(ing.item.id)
                    let invSnap = try transaction.getDocument(invRef)
                    let qty = invSnap.data()?["quantity"] as? Double ?? 0
                    if qty < needQty {
                        errorPointer?.pointee = NSError(domain: "ProductionService", code: 2008, userInfo: [NSLocalizedDescriptionKey: "Not enough \(ing.item.name). Need \(needQty), have \(qty)."])
                        return nil
                    }
                    inventorySnaps.append((invRef, invSnap, needQty))
                }

                for (invRef, invSnap, deductQty) in inventorySnaps {
                    let qty = invSnap.data()?["quantity"] as? Double ?? 0
                    var invData = invSnap.data() ?? [:]
                    invData["quantity"] = qty - deductQty
                    transaction.setData(invData, forDocument: invRef)
                }

                let startedAt = Date()
                let endsAt = startedAt.addingTimeInterval(cycleSeconds)
                transaction.updateData([
                    "isProducing": true,
                    "productionStartedAt": Timestamp(date: startedAt),
                    "productionEndsAt": Timestamp(date: endsAt),
                    "pendingOutputQuantity": scaledOutputQty,
                    "pendingOutputItemId": firstOutput.item.id,
                    "pendingOutputItemName": firstOutput.item.name
                ], forDocument: buildingRef)
                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }) { _, error in
            if let error = error { completion(.failure(error)) }
            else { completion(.success(())) }
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
        case .quarry, .stoneQuarry:
            return "raw-stone"
        case .sandQuarry:
            return "raw-sand"
        case .gravelQuarry:
            return "raw-gravel"
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
        case .quarry, .stoneQuarry:
            return "Raw Stone"
        case .sandQuarry:
            return "Raw Sand"
        case .gravelQuarry:
            return "Raw Gravel"
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
