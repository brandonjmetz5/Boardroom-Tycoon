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

    /// Base fuel cells per extractor cycle (level 1).
    /// Level N uses base * throughputMultiplier(N), so higher levels use more fuel as they output more.
    static let baseFuelPerExtractorCycle: Double = 10

    /// Inventory document ID for fuel (matches starter inventory and Item catalog).
    private let fuelInventoryDocID = "fuel-cell"

    /// Base cash cost per R&D cycle at level 1.
    private let baseResearchCycleCost: Double = 500

    /// Range of research points per cycle for a given building level.
    private func researchPointsRange(forLevel level: Int) -> ClosedRange<Int> {
        switch level {
        case 1: return 10...20
        case 2: return 20...35
        case 3: return 35...55
        case 4: return 55...80
        default: return 80...120
        }
    }

    /// Start an R&D research cycle: spends cash, schedules a timer, and stores pending research points on the building.
    func startResearchCycle(for userID: String, buildingID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(buildingID)

        db.runTransaction({ transaction, errorPointer in
            do {
                let profileSnap = try transaction.getDocument(profileRef)
                let buildingSnap = try transaction.getDocument(buildingRef)

                guard
                    let profileData = profileSnap.data(),
                    let buildingData = buildingSnap.data(),
                    let typeRaw = buildingData["type"] as? String,
                    let level = buildingData["level"] as? Int,
                    let currentCash = profileData["cash"] as? Double
                else {
                    errorPointer?.pointee = NSError(
                        domain: "ProductionService",
                        code: 2100,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid profile or building data."]
                    )
                    return nil
                }

                guard typeRaw == BuildingType.researchAndDevelopment.rawValue else {
                    errorPointer?.pointee = NSError(
                        domain: "ProductionService",
                        code: 2101,
                        userInfo: [NSLocalizedDescriptionKey: "Not an R&D building."]
                    )
                    return nil
                }

                if buildingData["isListedOnMarket"] as? Bool == true {
                    errorPointer?.pointee = NSError(
                        domain: "ProductionService",
                        code: 2102,
                        userInfo: [NSLocalizedDescriptionKey: "R&D building cannot run while listed."]
                    )
                    return nil
                }

                if buildingData["isProducing"] as? Bool == true {
                    errorPointer?.pointee = NSError(
                        domain: "ProductionService",
                        code: 2103,
                        userInfo: [NSLocalizedDescriptionKey: "R&D cycle already running."]
                    )
                    return nil
                }

                let levelMultiplier = 1.0 + 0.5 * Double(max(0, level - 1))
                let cycleCost = (self.baseResearchCycleCost * levelMultiplier).rounded()

                if currentCash < cycleCost {
                    errorPointer?.pointee = NSError(
                        domain: "ProductionService",
                        code: 2104,
                        userInfo: [NSLocalizedDescriptionKey: "Not enough cash for R&D cycle. Need $\(Int(cycleCost))."]
                    )
                    return nil
                }

                let range = self.researchPointsRange(forLevel: level)
                let points = Int.random(in: range)

                let startedAt = Date()
                #if DEBUG
                let cycleSeconds: TimeInterval = 10
                #else
                let cycleSeconds: TimeInterval = 60 * 15
                #endif
                let endsAt = startedAt.addingTimeInterval(cycleSeconds)

                transaction.updateData([
                    "cash": currentCash - cycleCost
                ], forDocument: profileRef)

                transaction.updateData([
                    "isProducing": true,
                    "productionStartedAt": Timestamp(date: startedAt),
                    "productionEndsAt": Timestamp(date: endsAt),
                    "pendingOutputQuantity": Double(points),
                    "pendingOutputItemId": NSNull(),
                    "pendingOutputItemName": NSNull(),
                    "pendingOutputQuality": NSNull()
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
            let resourceType = (buildingData["resourceType"] as? String).flatMap(ResourceType.init(rawValue:))
            let totalOutput = self.generateMineOutput(resourceType: resourceType, abundance: buildingAbundance, level: level)

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

                let typeRawValue = buildingData["type"] as? String ?? ""
                let pendingOutputQuantity = buildingData["pendingOutputQuantity"] as? Double ?? 0
                let pendingOutputQuality = buildingData["pendingOutputQuality"] as? Int

                // Research & Development building: award research points instead of inventory.
                if typeRawValue == BuildingType.researchAndDevelopment.rawValue {
                    let currentResearchPoints = profileData["researchPoints"] as? Int ?? 0
                    let awarded = Int(pendingOutputQuantity.rounded())
                    if awarded > 0 {
                        transaction.updateData([
                            "researchPoints": currentResearchPoints + awarded
                        ], forDocument: profileRef)
                    }

                    transaction.updateData([
                        "isProducing": false,
                        "productionStartedAt": NSNull(),
                        "productionEndsAt": NSNull(),
                        "pendingOutputQuantity": 0.0,
                        "pendingOutputItemId": NSNull(),
                        "pendingOutputItemName": NSNull(),
                        "pendingOutputQuality": NSNull()
                    ], forDocument: buildingRef)

                    return nil
                }

                if let resourceTypeRawValue = buildingData["resourceType"] as? String,
                   let resourceType = ResourceType(rawValue: resourceTypeRawValue) {
                    let baseInventoryDocID = self.inventoryDocumentID(for: resourceType)
                    let quality = pendingOutputQuality ?? 1
                    let inventoryDocID = quality > 1 ? "\(baseInventoryDocID)-q\(quality)" : baseInventoryDocID
                    let inventoryName = self.inventoryDisplayName(for: resourceType)
                    let inventoryRef = profileRef.collection("inventory").document(inventoryDocID)
                    let inventorySnapshot = try transaction.getDocument(inventoryRef)
                    let currentQuantity = inventorySnapshot.data()?["quantity"] as? Double ?? 0.0
                    let currentXP = profileData["xp"] as? Int ?? 0
                    let xpReward = 10
                    let updatedXP = currentXP + xpReward
                    let updatedLevel = self.levelForTotalXP(updatedXP)
                    let updatedBuildingSlotCount = self.buildingSlotCount(for: updatedLevel)
                    var inventoryData: [String: Any] = [
                        "id": inventoryDocID,
                        "name": inventoryName,
                        "category": "Raw Material",
                        "isFractional": false,
                        "quantity": currentQuantity + pendingOutputQuantity
                    ]
                    inventoryData["quality"] = quality
                    inventoryData["baseItemId"] = baseInventoryDocID
                    transaction.setData(inventoryData, forDocument: inventoryRef)
                    transaction.updateData(["xp": updatedXP, "level": updatedLevel, "buildingSlotCount": updatedBuildingSlotCount], forDocument: profileRef)
                } else if let outputItemId = buildingData["pendingOutputItemId"] as? String,
                          let outputItemName = buildingData["pendingOutputItemName"] as? String {
                    let quality = pendingOutputQuality ?? 1
                    let baseId = outputItemId
                    let inventoryDocID = quality > 1 ? "\(baseId)-q\(quality)" : baseId
                    let inventoryRef = profileRef.collection("inventory").document(inventoryDocID)
                    let inventorySnapshot = try transaction.getDocument(inventoryRef)
                    let existingData = inventorySnapshot.data()
                    let currentQuantity = existingData?["quantity"] as? Double ?? 0.0
                    let category = existingData?["category"] as? String ?? "Refined Material"
                    let isFractional = existingData?["isFractional"] as? Bool ?? false
                    var inventoryData: [String: Any] = [
                        "id": inventoryDocID,
                        "name": outputItemName,
                        "category": category,
                        "isFractional": isFractional,
                        "quantity": currentQuantity + pendingOutputQuantity
                    ]
                    inventoryData["quality"] = quality
                    inventoryData["baseItemId"] = baseId
                    transaction.setData(inventoryData, forDocument: inventoryRef)
                }

                transaction.updateData([
                    "isProducing": false,
                    "productionStartedAt": NSNull(),
                    "productionEndsAt": NSNull(),
                    "pendingOutputQuantity": 0.0,
                    "pendingOutputItemId": NSNull(),
                    "pendingOutputItemName": NSNull(),
                    "pendingOutputQuality": NSNull()
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
    /// Optionally accepts a target quality; inputs must have quality >= target.
    func startRecipeProduction(for userID: String, building: Building, recipe: Recipe, targetQuality: Int = 1, completion: @escaping (Result<Void, Error>) -> Void) {
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

                // For quality-aware production, inputs must have quality >= targetQuality.
                // We model quality by suffixing inventory doc IDs with "-qX" and also allow base quality (no suffix) when targetQuality == 1.
                var inventoryUpdates: [(DocumentReference, Double)] = []
                for (ing, needQty) in scaledInputs {
                    var remaining = needQty
                    let baseId = ing.item.id
                    var candidates: [DocumentReference] = []
                    let inventoryCollection = profileRef.collection("inventory")

                    if targetQuality > 1 {
                        // Prefer exact quality doc.
                        candidates.append(inventoryCollection.document("\(baseId)-q\(targetQuality)"))
                    } else {
                        // Base quality uses original ID.
                        candidates.append(inventoryCollection.document(baseId))
                    }

                    var totalAvailable: Double = 0
                    for ref in candidates {
                        let snap = try transaction.getDocument(ref)
                        let qty = snap.data()?["quantity"] as? Double ?? 0
                        totalAvailable += qty
                    }

                    if totalAvailable < remaining {
                        errorPointer?.pointee = NSError(
                            domain: "ProductionService",
                            code: 2008,
                            userInfo: [NSLocalizedDescriptionKey: "Not enough \(ing.item.name) at required quality. Need \(needQty), have \(totalAvailable)."]
                        )
                        return nil
                    }

                    for ref in candidates {
                        if remaining <= 0 { break }
                        let snap = try transaction.getDocument(ref)
                        let qty = snap.data()?["quantity"] as? Double ?? 0
                        if qty <= 0 { continue }
                        let deduct = min(qty, remaining)
                        remaining -= deduct
                        inventoryUpdates.append((ref, deduct))
                    }
                }

                for (ref, deductQty) in inventoryUpdates {
                    let snap = try transaction.getDocument(ref)
                    let qty = snap.data()?["quantity"] as? Double ?? 0
                    var invData = snap.data() ?? [:]
                    invData["quantity"] = qty - deductQty
                    transaction.setData(invData, forDocument: ref)
                }

                let startedAt = Date()
                let endsAt = startedAt.addingTimeInterval(cycleSeconds)
                transaction.updateData([
                    "isProducing": true,
                    "productionStartedAt": Timestamp(date: startedAt),
                    "productionEndsAt": Timestamp(date: endsAt),
                    "pendingOutputQuantity": scaledOutputQty,
                    "pendingOutputItemId": firstOutput.item.id,
                    "pendingOutputItemName": firstOutput.item.name,
                    "pendingOutputQuality": targetQuality
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

    // MARK: - Extractor Output (abundance + level)

    /// Base mean output by resource type (used for abundance scaling).
    private static func baseMean(for resourceType: ResourceType?) -> Double {
        switch resourceType {
        case .gold?: return 15
        case .silver?: return 16
        case .diamond?: return 8
        case .oil?: return 20
        case .coal?: return 18
        case .iron?: return 17
        case .quarry?, .sandQuarry?, .stoneQuarry?, .gravelQuarry?: return 14
        default: return 15
        }
    }

    /// Returns the min and max output per cycle for an extractor with given abundance and level.
    /// - **Abundance** (0–100) is revealed when prospecting finishes; higher abundance = better base range.
    /// - **Building level** increases the output range via throughput multiplier. Upgrading compensates for
    ///   low abundance: e.g. abundance 60 at level 2 produces more than abundance 60 at level 1.
    static func extractorOutputRange(abundance: Int, level: Int, resourceType: ResourceType?) -> (min: Int, max: Int) {
        let baseMean = Self.baseMean(for: resourceType)
        let clampedAbundance = max(1, min(100, abundance))
        let abundanceMultiplier = 0.5 + Double(clampedAbundance) / 100.0
        let mean = baseMean * abundanceMultiplier

        let baseMin = max(1.0, mean * 0.8)
        let baseMax = max(baseMin, mean * 1.2)

        let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: level)
        let scaledMin = Int(BuildingLevelCatalog.scaleQuantity(baseMin, throughputMultiplier: mult))
        let scaledMax = Int(BuildingLevelCatalog.scaleQuantity(baseMax, throughputMultiplier: mult))

        return (max(1, scaledMin), max(scaledMin, scaledMax))
    }

    /// Generate a base output for an extractor building using abundance and level.
    /// Abundance determines base range; level scales the output via throughput multiplier.
    private func generateMineOutput(resourceType: ResourceType?, abundance: Int, level: Int) -> Int {
        let (minOut, maxOut) = Self.extractorOutputRange(abundance: abundance, level: level, resourceType: resourceType)
        return Int.random(in: minOut...maxOut)
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
