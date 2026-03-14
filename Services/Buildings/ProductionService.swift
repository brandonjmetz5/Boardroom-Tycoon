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

    /// Fuel cells consumed per production cycle per extractor (mine/rig/quarry).
    static let fuelRequiredPerCycle: Double = 2

    /// Inventory document ID for fuel (matches starter inventory and Item catalog).
    private let fuelInventoryDocID = "fuel-cell"

    func startProduction(for userID: String, buildingID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(buildingID)
        let machinesRef = buildingRef.collection("machines")
        let fuelRef = profileRef.collection("inventory").document(fuelInventoryDocID)

        // Transaction cannot query collections; fetch building + machines first, compute output, then run transaction.
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
            let buildingAbundance = buildingData["abundance"] as? Int
            let buildingStability = buildingData["stability"] as? Int

            machinesRef.getDocuments { [weak self] machinesSnapshot, machinesError in
                guard let self else { return }
                if let machinesError = machinesError {
                    completion(.failure(machinesError))
                    return
                }
                let machineDocs = machinesSnapshot?.documents ?? []
                let totalOutput: Int
                if !machineDocs.isEmpty {
                    totalOutput = machineDocs.reduce(0) { sum, doc in
                        let d = doc.data()
                        let a = d["abundance"] as? Int ?? buildingAbundance ?? 50
                        let s = d["stability"] as? Int ?? buildingStability ?? 50
                        return sum + self.generateMineOutput(abundance: a, stability: s)
                    }
                } else if let a = buildingAbundance, let s = buildingStability {
                    totalOutput = self.generateMineOutput(abundance: a, stability: s)
                } else {
                    completion(.failure(NSError(domain: "ProductionService", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Missing mine stat data."])))
                    return
                }

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
                        if fuelQuantity < Self.fuelRequiredPerCycle {
                            errorPointer?.pointee = NSError(
                                domain: "ProductionService",
                                code: 2006,
                                userInfo: [NSLocalizedDescriptionKey: "Not enough fuel. Each production cycle costs \(Int(Self.fuelRequiredPerCycle)) Fuel Cells."]
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

                        let newFuelQuantity = fuelQuantity - Self.fuelRequiredPerCycle
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

    /// Start recipe-based production: consume inputs from inventory, set building producing with output.
    func startRecipeProduction(for userID: String, building: Building, recipe: Recipe, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(building.id)

        guard let firstOutput = recipe.outputItems.first else {
            completion(.failure(NSError(domain: "ProductionService", code: 2010, userInfo: [NSLocalizedDescriptionKey: "Recipe has no output."])))
            return
        }

        #if DEBUG
        let cycleSeconds: TimeInterval = 10
        #else
        let cycleSeconds = TimeInterval(recipe.cycleTimeInMinutes * 60)
        #endif

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                // All reads first (Firestore requirement)
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

                var inventorySnaps: [(DocumentReference, DocumentSnapshot, RecipeIngredient)] = []
                for input in recipe.inputItems {
                    let invRef = profileRef.collection("inventory").document(input.item.id)
                    let invSnap = try transaction.getDocument(invRef)
                    let qty = invSnap.data()?["quantity"] as? Double ?? 0
                    if qty < input.quantity {
                        errorPointer?.pointee = NSError(domain: "ProductionService", code: 2008, userInfo: [NSLocalizedDescriptionKey: "Not enough \(input.item.name). Need \(input.quantity), have \(qty)."])
                        return nil
                    }
                    inventorySnaps.append((invRef, invSnap, input))
                }

                // All writes after all reads
                for (invRef, invSnap, input) in inventorySnaps {
                    let qty = invSnap.data()?["quantity"] as? Double ?? 0
                    var invData = invSnap.data() ?? ["id": input.item.id, "name": input.item.name, "category": input.item.category.rawValue, "isFractional": input.item.isFractional]
                    invData["quantity"] = qty - input.quantity
                    transaction.setData(invData, forDocument: invRef)
                }

                let startedAt = Date()
                let endsAt = startedAt.addingTimeInterval(cycleSeconds)
                transaction.updateData([
                    "isProducing": true,
                    "productionStartedAt": Timestamp(date: startedAt),
                    "productionEndsAt": Timestamp(date: endsAt),
                    "pendingOutputQuantity": firstOutput.quantity,
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

    // MARK: - Per-machine production (each machine runs its own cycle)

    /// Start production on a single extractor machine. Consumes 2 fuel, sets machine's production state.
    func startProductionForMachine(for userID: String, buildingID: String, machineID: String, resourceType: ResourceType, abundance: Int, stability: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(buildingID)
        let machineRef = buildingRef.collection("machines").document(machineID)
        let fuelRef = profileRef.collection("inventory").document(fuelInventoryDocID)

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                let buildingSnap = try transaction.getDocument(buildingRef)
                let machineSnap = try transaction.getDocument(machineRef)
                let fuelSnap = try transaction.getDocument(fuelRef)
                guard let buildingData = buildingSnap.data() else {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Building not found."])
                    return nil
                }
                guard let machineData = machineSnap.data() else {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Machine not found."])
                    return nil
                }
                if (buildingData["isListedOnMarket"] as? Bool) ?? false {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2004, userInfo: [NSLocalizedDescriptionKey: "Building is listed; cannot produce."])
                    return nil
                }
                if (machineData["isProducing"] as? Bool) == true {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2007, userInfo: [NSLocalizedDescriptionKey: "This machine is already producing."])
                    return nil
                }
                let fuelQty = fuelSnap.data()?["quantity"] as? Double ?? 0
                if fuelQty < Self.fuelRequiredPerCycle {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2006, userInfo: [NSLocalizedDescriptionKey: "Not enough fuel. Need \(Int(Self.fuelRequiredPerCycle)) Fuel Cells."])
                    return nil
                }
                let output = self.generateMineOutput(abundance: abundance, stability: stability)
                let startedAt = Date()
                #if DEBUG
                let cycleSeconds: TimeInterval = 10
                #else
                let cycleSeconds: TimeInterval = 60 * 60
                #endif
                let endsAt = startedAt.addingTimeInterval(cycleSeconds)
                var updatedMachine = machineData
                updatedMachine["isProducing"] = true
                updatedMachine["productionStartedAt"] = Timestamp(date: startedAt)
                updatedMachine["productionEndsAt"] = Timestamp(date: endsAt)
                updatedMachine["pendingOutputQuantity"] = Double(output)
                updatedMachine["pendingOutputItemId"] = NSNull()
                updatedMachine["pendingOutputItemName"] = NSNull()
                transaction.setData(updatedMachine, forDocument: machineRef)
                var fuelData = fuelSnap.data() ?? [:]
                fuelData["quantity"] = fuelQty - Self.fuelRequiredPerCycle
                transaction.setData(fuelData, forDocument: fuelRef)
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

    /// Start recipe production on a single machine. Consumes recipe inputs, sets machine's production state.
    func startRecipeProductionForMachine(for userID: String, buildingID: String, machineID: String, building: Building, recipe: Recipe, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(buildingID)
        let machineRef = buildingRef.collection("machines").document(machineID)
        guard let firstOutput = recipe.outputItems.first else {
            completion(.failure(NSError(domain: "ProductionService", code: 2010, userInfo: [NSLocalizedDescriptionKey: "Recipe has no output."])))
            return
        }
        #if DEBUG
        let cycleSeconds: TimeInterval = 10
        #else
        let cycleSeconds = TimeInterval(recipe.cycleTimeInMinutes * 60)
        #endif

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                // All reads first (Firestore requirement)
                let buildingSnap = try transaction.getDocument(buildingRef)
                let machineSnap = try transaction.getDocument(machineRef)
                guard buildingSnap.data() != nil, var machineData = machineSnap.data() else {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Building or machine not found."])
                    return nil
                }
                if (buildingSnap.data()?["isListedOnMarket"] as? Bool) == true {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2004, userInfo: [NSLocalizedDescriptionKey: "Building cannot produce while listed."])
                    return nil
                }
                if (machineData["isProducing"] as? Bool) == true {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2007, userInfo: [NSLocalizedDescriptionKey: "This machine is already producing."])
                    return nil
                }

                var inventorySnaps: [(DocumentReference, DocumentSnapshot, Double)] = []
                for input in recipe.inputItems {
                    let invRef = profileRef.collection("inventory").document(input.item.id)
                    let invSnap = try transaction.getDocument(invRef)
                    let qty = invSnap.data()?["quantity"] as? Double ?? 0
                    if qty < input.quantity {
                        errorPointer?.pointee = NSError(domain: "ProductionService", code: 2008, userInfo: [NSLocalizedDescriptionKey: "Not enough \(input.item.name). Need \(input.quantity), have \(qty)."])
                        return nil
                    }
                    inventorySnaps.append((invRef, invSnap, input.quantity))
                }

                // All writes after all reads
                for (invRef, invSnap, deductQty) in inventorySnaps {
                    let qty = invSnap.data()?["quantity"] as? Double ?? 0
                    var invData = invSnap.data() ?? [:]
                    invData["quantity"] = qty - deductQty
                    transaction.setData(invData, forDocument: invRef)
                }
                let startedAt = Date()
                let endsAt = startedAt.addingTimeInterval(cycleSeconds)
                machineData["isProducing"] = true
                machineData["productionStartedAt"] = Timestamp(date: startedAt)
                machineData["productionEndsAt"] = Timestamp(date: endsAt)
                machineData["pendingOutputQuantity"] = firstOutput.quantity
                machineData["pendingOutputItemId"] = firstOutput.item.id
                machineData["pendingOutputItemName"] = firstOutput.item.name
                transaction.setData(machineData, forDocument: machineRef)
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

    /// Collect output from a single machine (extractor or recipe). Adds to inventory, clears machine production state.
    func collectProductionForMachine(for userID: String, buildingID: String, machineID: String, resourceType: ResourceType?, pendingOutputQuantity: Double, pendingOutputItemId: String?, pendingOutputItemName: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(buildingID)
        let machineRef = buildingRef.collection("machines").document(machineID)

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                // All reads first (Firestore requirement)
                let machineSnap = try transaction.getDocument(machineRef)
                guard var machineData = machineSnap.data() else {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Machine not found."])
                    return nil
                }
                guard (machineData["isProducing"] as? Bool) == true,
                      let endsAt = (machineData["productionEndsAt"] as? Timestamp)?.dateValue(), endsAt <= Date() else {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2003, userInfo: [NSLocalizedDescriptionKey: "Production not finished yet."])
                    return nil
                }
                let qty = machineData["pendingOutputQuantity"] as? Double ?? 0

                let invRef: DocumentReference?
                let invDocID: String?
                let invName: String?
                let isExtractor: Bool
                if let rt = resourceType {
                    invDocID = self.inventoryDocumentID(for: rt)
                    invName = self.inventoryDisplayName(for: rt)
                    invRef = profileRef.collection("inventory").document(invDocID!)
                    isExtractor = true
                } else if let outId = pendingOutputItemId, let outName = pendingOutputItemName {
                    invDocID = outId
                    invName = outName
                    invRef = profileRef.collection("inventory").document(outId)
                    isExtractor = false
                } else {
                    invRef = nil
                    invDocID = nil
                    invName = nil
                    isExtractor = false
                }

                let invSnap: DocumentSnapshot?
                let profileSnap: DocumentSnapshot?
                if let ref = invRef {
                    invSnap = try transaction.getDocument(ref)
                    profileSnap = isExtractor ? try transaction.getDocument(profileRef) : nil
                } else {
                    invSnap = nil
                    profileSnap = nil
                }

                // All writes after all reads
                if let ref = invRef, let snap = invSnap {
                    if isExtractor, let invDocID = invDocID, let invName = invName {
                        let current = snap.data()?["quantity"] as? Double ?? 0
                        let invData: [String: Any] = [
                            "id": invDocID, "name": invName, "category": "Raw Material", "isFractional": false,
                            "quantity": current + qty
                        ]
                        transaction.setData(invData, forDocument: ref)
                        if let profileData = profileSnap?.data() {
                            let xp = profileData["xp"] as? Int ?? 0
                            let level = self.levelForTotalXP(xp + 10)
                            let slots = self.buildingSlotCount(for: level)
                            transaction.updateData(["xp": xp + 10, "level": level, "buildingSlotCount": slots], forDocument: profileRef)
                        }
                    } else if let outId = pendingOutputItemId, let outName = pendingOutputItemName {
                        let existing = snap.data() ?? [:]
                        let current = existing["quantity"] as? Double ?? 0
                        var invData = existing
                        invData["id"] = outId
                        invData["name"] = outName
                        invData["quantity"] = current + qty
                        if invData["category"] == nil { invData["category"] = "Refined Material" }
                        if invData["isFractional"] == nil { invData["isFractional"] = false }
                        transaction.setData(invData, forDocument: ref)
                    }
                }
                machineData["isProducing"] = false
                machineData["productionStartedAt"] = NSNull()
                machineData["productionEndsAt"] = NSNull()
                machineData["pendingOutputQuantity"] = NSNull()
                machineData["pendingOutputItemId"] = NSNull()
                machineData["pendingOutputItemName"] = NSNull()
                transaction.setData(machineData, forDocument: machineRef)
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

    // MARK: - All-or-nothing: start all machines / collect all

    /// Start production on every machine in the building. Fails if any machine is already producing or if resources are insufficient for all.
    func startProductionForAllMachines(for userID: String, building: Building, machines: [Machine], recipe: Recipe?, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(building.id)
        let fuelRef = profileRef.collection("inventory").document(fuelInventoryDocID)
        let isExtractor = building.type == .mine || building.type == .rig || building.type == .quarry

        if isExtractor {
            guard let rt = building.resourceType else {
                completion(.failure(NSError(domain: "ProductionService", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Missing resource type."])))
                return
            }
            let requiredFuel = Self.fuelRequiredPerCycle * Double(machines.count)
            db.runTransaction({ [weak self] transaction, errorPointer in
                guard let self else { return nil }
                do {
                    let buildingSnap = try transaction.getDocument(buildingRef)
                    let fuelSnap = try transaction.getDocument(fuelRef)
                    guard (buildingSnap.data()?["isListedOnMarket"] as? Bool) != true else {
                        errorPointer?.pointee = NSError(domain: "ProductionService", code: 2004, userInfo: [NSLocalizedDescriptionKey: "Building is listed."])
                        return nil
                    }
                    let fuelQty = fuelSnap.data()?["quantity"] as? Double ?? 0
                    if fuelQty < requiredFuel {
                        errorPointer?.pointee = NSError(domain: "ProductionService", code: 2006, userInfo: [NSLocalizedDescriptionKey: "Need \(Int(requiredFuel)) Fuel Cells for \(machines.count) machine(s)."])
                        return nil
                    }
                    var machineSnaps: [(DocumentReference, DocumentSnapshot)] = []
                    for m in machines {
                        let ref = buildingRef.collection("machines").document(m.id)
                        let snap = try transaction.getDocument(ref)
                        machineSnaps.append((ref, snap))
                    }
                    for (_, snap) in machineSnaps {
                        if (snap.data()?["isProducing"] as? Bool) == true {
                            errorPointer?.pointee = NSError(domain: "ProductionService", code: 2007, userInfo: [NSLocalizedDescriptionKey: "A machine is already producing. Collect first or wait."])
                            return nil
                        }
                    }
                    let startedAt = Date()
                    #if DEBUG
                    let cycleSeconds: TimeInterval = 10
                    #else
                    let cycleSeconds: TimeInterval = 60 * 60
                    #endif
                    let endsAt = startedAt.addingTimeInterval(cycleSeconds)
                    for (idx, (ref, snap)) in machineSnaps.enumerated() {
                        let m = machines[idx]
                        let a = m.abundance ?? building.abundance ?? 50
                        let s = m.stability ?? building.stability ?? 50
                        let output = self.generateMineOutput(abundance: a, stability: s)
                        var data = snap.data() ?? [:]
                        data["isProducing"] = true
                        data["productionStartedAt"] = Timestamp(date: startedAt)
                        data["productionEndsAt"] = Timestamp(date: endsAt)
                        data["pendingOutputQuantity"] = Double(output)
                        data["pendingOutputItemId"] = NSNull()
                        data["pendingOutputItemName"] = NSNull()
                        transaction.setData(data, forDocument: ref)
                    }
                    var fuelData = fuelSnap.data() ?? [:]
                    fuelData["quantity"] = fuelQty - requiredFuel
                    transaction.setData(fuelData, forDocument: fuelRef)
                    return nil
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
            }) { _, error in
                if let error = error { completion(.failure(error)) }
                else { completion(.success(())) }
            }
            return
        }

        guard let r = recipe, let firstOutput = r.outputItems.first else {
            completion(.failure(NSError(domain: "ProductionService", code: 2010, userInfo: [NSLocalizedDescriptionKey: "Recipe required."])))
            return
        }
        #if DEBUG
        let cycleSeconds: TimeInterval = 10
        #else
        let cycleSeconds = TimeInterval(r.cycleTimeInMinutes * 60)
        #endif
        let startedAt = Date()
        let endsAt = startedAt.addingTimeInterval(cycleSeconds)
        let multiplier = Double(machines.count)

        db.runTransaction({ [weak self] transaction, errorPointer in
            guard let self else { return nil }
            do {
                let buildingSnap = try transaction.getDocument(buildingRef)
                guard (buildingSnap.data()?["isListedOnMarket"] as? Bool) != true else {
                    errorPointer?.pointee = NSError(domain: "ProductionService", code: 2004, userInfo: [NSLocalizedDescriptionKey: "Building is listed."])
                    return nil
                }
                var machineRefs: [(DocumentReference, DocumentSnapshot)] = []
                for m in machines {
                    let ref = buildingRef.collection("machines").document(m.id)
                    let snap = try transaction.getDocument(ref)
                    machineRefs.append((ref, snap))
                    if (snap.data()?["isProducing"] as? Bool) == true {
                        errorPointer?.pointee = NSError(domain: "ProductionService", code: 2007, userInfo: [NSLocalizedDescriptionKey: "A machine is already producing."])
                        return nil
                    }
                }
                var inputSnaps: [(DocumentReference, DocumentSnapshot, Double)] = []
                for input in r.inputItems {
                    let ref = profileRef.collection("inventory").document(input.item.id)
                    let snap = try transaction.getDocument(ref)
                    let qty = snap.data()?["quantity"] as? Double ?? 0
                    let need = input.quantity * multiplier
                    if qty < need {
                        errorPointer?.pointee = NSError(domain: "ProductionService", code: 2008, userInfo: [NSLocalizedDescriptionKey: "Not enough \(input.item.name). Need \(Int(need)), have \(Int(qty))."])
                        return nil
                    }
                    inputSnaps.append((ref, snap, input.quantity))
                }
                for (ref, snap, deductPerUnit) in inputSnaps {
                    let qty = snap.data()?["quantity"] as? Double ?? 0
                    var data = snap.data() ?? [:]
                    data["quantity"] = qty - (deductPerUnit * multiplier)
                    transaction.setData(data, forDocument: ref)
                }
                for (ref, snap) in machineRefs {
                    var data = snap.data() ?? [:]
                    data["isProducing"] = true
                    data["productionStartedAt"] = Timestamp(date: startedAt)
                    data["productionEndsAt"] = Timestamp(date: endsAt)
                    data["pendingOutputQuantity"] = firstOutput.quantity
                    data["pendingOutputItemId"] = firstOutput.item.id
                    data["pendingOutputItemName"] = firstOutput.item.name
                    transaction.setData(data, forDocument: ref)
                }
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

    /// Collect from every machine that is ready. Returns count of machines collected.
    func collectProductionForAllMachines(for userID: String, building: Building, machines: [Machine], completion: @escaping (Result<Int, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(building.id)
        let now = Date()
        let ready = machines.filter { m in (m.isProducing ?? false) && (m.productionEndsAt ?? .distantFuture) <= now }
        if ready.isEmpty {
            completion(.success(0))
            return
        }
        var collected = 0
        let group = DispatchGroup()
        for m in ready {
            group.enter()
            let qty = m.pendingOutputQuantity ?? 0
            let outId = m.pendingOutputItemId
            let outName = m.pendingOutputItemName
            let rt = building.resourceType
            collectProductionForMachine(for: userID, buildingID: building.id, machineID: m.id, resourceType: rt, pendingOutputQuantity: qty, pendingOutputItemId: outId, pendingOutputItemName: outName) { result in
                if case .success = result { collected += 1 }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion(.success(collected))
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
