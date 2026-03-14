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
                let pendingOutputItemId = data["pendingOutputItemId"] as? String
                let pendingOutputItemName = data["pendingOutputItemName"] as? String

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
                    pendingOutputItemId: pendingOutputItemId,
                    pendingOutputItemName: pendingOutputItemName,
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
                let firstMachineID = "machine-starter-1"
                let firstMachineData: [String: Any] = [
                    "id": firstMachineID,
                    "name": Machine.extractorMachineName,
                    "level": 0,
                    "efficiencyBonus": 0,
                    "abundance": 50,
                    "stability": 55
                ]
                transaction.setData(firstMachineData, forDocument: starterMineRef.collection("machines").document(firstMachineID))
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

                        let firstMachineID = "machine-\(UUID().uuidString)"
                        let firstMachineData: [String: Any] = [
                            "id": firstMachineID,
                            "name": "Machine",
                            "level": 0,
                            "efficiencyBonus": 0,
                            "outputValuePerCycle": Machine.defaultOutputValuePerCycle
                        ]
                        transaction.setData(firstMachineData, forDocument: newBuildingRef.collection("machines").document(firstMachineID))

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
                    let buildingData = buildingSnapshot.data()
                else {
                    let error = NSError(
                        domain: "BuildingService",
                        code: 1201,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid building or profile data."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let isListedOnMarket = (buildingData["isListedOnMarket"] as? Bool) ?? false
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

    // MARK: - Machines (subcollection: buildings/{id}/machines)

    func fetchMachines(for userID: String, buildingID: String, completion: @escaping (Result<[Machine], Error>) -> Void) {
        let machinesRef = db.collection("playerProfiles").document(userID).collection("buildings").document(buildingID).collection("machines")
        machinesRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            let machines = documents.compactMap { doc -> Machine? in
                let data = doc.data()
                guard let id = data["id"] as? String, let name = data["name"] as? String else { return nil }
                let level = data["level"] as? Int ?? 0
                let efficiencyBonus = data["efficiencyBonus"] as? Double ?? 0
                let abundance = data["abundance"] as? Int
                let stability = data["stability"] as? Int
                let outputValuePerCycle = data["outputValuePerCycle"] as? Double
                let isProducing = data["isProducing"] as? Bool
                let productionStartedAt: Date? = (data["productionStartedAt"] as? Timestamp)?.dateValue()
                let productionEndsAt: Date? = (data["productionEndsAt"] as? Timestamp)?.dateValue()
                let pendingOutputQuantity = data["pendingOutputQuantity"] as? Double
                let pendingOutputItemId = data["pendingOutputItemId"] as? String
                let pendingOutputItemName = data["pendingOutputItemName"] as? String
                return Machine(
                    id: id,
                    name: name,
                    level: level,
                    efficiencyBonus: efficiencyBonus,
                    abundance: abundance,
                    stability: stability,
                    outputValuePerCycle: outputValuePerCycle,
                    isProducing: isProducing,
                    productionStartedAt: productionStartedAt,
                    productionEndsAt: productionEndsAt,
                    pendingOutputQuantity: pendingOutputQuantity,
                    pendingOutputItemId: pendingOutputItemId,
                    pendingOutputItemName: pendingOutputItemName
                )
            }
            completion(.success(machines.sorted { $0.id < $1.id }))
        }
    }

    /// Ensures a non-extractor building has at least one machine when empty (e.g. bought before we created first machine).
    func ensureFirstNonExtractorMachine(for userID: String, building: Building, completion: @escaping (Result<Void, Error>) -> Void) {
        guard building.type != .mine && building.type != .rig && building.type != .quarry else {
            completion(.success(()))
            return
        }
        let machinesRef = db.collection("playerProfiles").document(userID).collection("buildings").document(building.id).collection("machines")
        machinesRef.getDocuments { [weak self] snapshot, error in
            guard self != nil else { return }
            if let error = error {
                completion(.failure(error))
                return
            }
            if let snapshot = snapshot, !snapshot.documents.isEmpty {
                completion(.success(()))
                return
            }
            let machineID = "machine-\(UUID().uuidString)"
            let machineData: [String: Any] = [
                "id": machineID,
                "name": "Machine",
                "level": 0,
                "efficiencyBonus": 0,
                "outputValuePerCycle": Machine.defaultOutputValuePerCycle
            ]
            machinesRef.document(machineID).setData(machineData) { err in
                if let err = err { completion(.failure(err)) }
                else { completion(.success(())) }
            }
        }
    }

    /// Ensures an extractor building has at least one machine (drill) from building's abundance/stability. Call after fetchMachines if empty.
    func ensureFirstExtractorMachine(for userID: String, building: Building, completion: @escaping (Result<Void, Error>) -> Void) {
        guard building.type == .mine || building.type == .rig || building.type == .quarry,
              let abundance = building.abundance, let stability = building.stability else {
            completion(.success(()))
            return
        }
        let machinesRef = db.collection("playerProfiles").document(userID).collection("buildings").document(building.id).collection("machines")
        machinesRef.getDocuments { [weak self] snapshot, error in
            guard let self else { return }
            if let error = error {
                completion(.failure(error))
                return
            }
            if let snapshot = snapshot, !snapshot.documents.isEmpty {
                completion(.success(()))
                return
            }
            let machineID = "machine-\(UUID().uuidString)"
            let machineData: [String: Any] = [
                "id": machineID,
                "name": Machine.extractorMachineName,
                "level": 0,
                "efficiencyBonus": 0,
                "abundance": abundance,
                "stability": stability
            ]
            machinesRef.document(machineID).setData(machineData) { err in
                if let err = err { completion(.failure(err)) }
                else { completion(.success(())) }
            }
        }
    }

    /// Building level 1–5. Capacity = level. Requires 1 of each building upgrade item per level.
    static let maxBuildingLevel = 5
    static let baseMachinePrice: Double = 600
    /// Cash for next machine = baseMachinePrice * (currentMachineCount + 1)
    static func addMachineCashCost(currentMachineCount: Int) -> Double {
        baseMachinePrice * Double(currentMachineCount + 1)
    }

    func upgradeBuildingLevel(for userID: String, buildingID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(buildingID)
        let inventoryRef = profileRef.collection("inventory")

        db.runTransaction({ transaction, errorPointer in
            do {
                let buildingSnapshot = try transaction.getDocument(buildingRef)
                guard let buildingData = buildingSnapshot.data(),
                      let level = buildingData["level"] as? Int,
                      let capacity = buildingData["capacity"] as? Int else {
                    errorPointer?.pointee = NSError(domain: "BuildingService", code: 1301, userInfo: [NSLocalizedDescriptionKey: "Building not found."])
                    return nil
                }
                if level >= Self.maxBuildingLevel {
                    errorPointer?.pointee = NSError(domain: "BuildingService", code: 1302, userInfo: [NSLocalizedDescriptionKey: "Building is already max level."])
                    return nil
                }
                let required = UpgradeCatalog.buildingUpgradeRequirement(forLevel: level)
                guard !required.isEmpty else {
                    errorPointer?.pointee = NSError(domain: "BuildingService", code: 1303, userInfo: [NSLocalizedDescriptionKey: "Invalid level for upgrade."])
                    return nil
                }
                for (itemID, requiredQty) in required {
                    let invRef = inventoryRef.document(itemID)
                    let invSnap = try transaction.getDocument(invRef)
                    let qty = invSnap.data()?["quantity"] as? Double ?? 0
                    if qty < requiredQty {
                        let label = UpgradeCatalog.buildingUpgradeRequirementLabel(forLevel: level)
                        errorPointer?.pointee = NSError(domain: "BuildingService", code: 1303, userInfo: [NSLocalizedDescriptionKey: "Need \(label). Missing or insufficient: \(itemID)."])
                        return nil
                    }
                    var invData = invSnap.data() ?? [:]
                    invData["quantity"] = qty - requiredQty
                    transaction.setData(invData, forDocument: invRef)
                }
                let newLevel = level + 1
                let newCapacity = newLevel
                transaction.updateData(["level": newLevel, "capacity": newCapacity], forDocument: buildingRef)
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

    func addMachine(for userID: String, building: Building, isExtractor: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(building.id)
        let machinesRef = buildingRef.collection("machines")

        fetchMachines(for: userID, buildingID: building.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
                return
            case .success(let machines):
                let currentCount = machines.count
                if currentCount >= building.capacity {
                    completion(.failure(NSError(domain: "BuildingService", code: 1401, userInfo: [NSLocalizedDescriptionKey: "No capacity for more machines. Upgrade the building first."])))
                    return
                }
                let cost = Self.addMachineCashCost(currentMachineCount: currentCount)
                let abundance = building.abundance
                let stability = building.stability

                self.db.runTransaction({ transaction, errorPointer in
                    do {
                        let profileSnap = try transaction.getDocument(profileRef)
                        guard let cash = profileSnap.data()?["cash"] as? Double else {
                            errorPointer?.pointee = NSError(domain: "BuildingService", code: 1402, userInfo: [NSLocalizedDescriptionKey: "Invalid profile."])
                            return nil
                        }
                        if cash < cost {
                            errorPointer?.pointee = NSError(domain: "BuildingService", code: 1403, userInfo: [NSLocalizedDescriptionKey: "Not enough cash. Cost: $\(Int(cost))."])
                            return nil
                        }
                        let machineID = "machine-\(UUID().uuidString)"
                        var machineData: [String: Any] = [
                            "id": machineID,
                            "name": isExtractor ? Machine.extractorMachineName : "Machine",
                            "level": 0,
                            "efficiencyBonus": 0
                        ]
                        if isExtractor, let a = abundance, let s = stability {
                            machineData["abundance"] = a
                            machineData["stability"] = s
                        } else {
                            machineData["outputValuePerCycle"] = Machine.defaultOutputValuePerCycle
                        }
                        transaction.setData(machineData, forDocument: machinesRef.document(machineID))
                        transaction.updateData(["cash": cash - cost], forDocument: profileRef)
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
        }
    }

    /// Consume machine upgrade items required for this building type; extractor: +2 abundance/stability (cap 100); non-extractor: +0.5 output (cap 5).
    func upgradeMachine(for userID: String, buildingID: String, machineID: String, buildingType: BuildingType, isExtractor: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingRef = profileRef.collection("buildings").document(buildingID)
        let machineRef = buildingRef.collection("machines").document(machineID)
        let inventoryRef = profileRef.collection("inventory")
        let required = UpgradeCatalog.machineUpgradeRequirement(for: buildingType)

        db.runTransaction({ transaction, errorPointer in
            do {
                let machineSnap = try transaction.getDocument(machineRef)
                guard var machineData = machineSnap.data(), machineData["id"] as? String != nil else {
                    errorPointer?.pointee = NSError(domain: "BuildingService", code: 1501, userInfo: [NSLocalizedDescriptionKey: "Machine not found."])
                    return nil
                }
                guard !required.isEmpty else {
                    errorPointer?.pointee = NSError(domain: "BuildingService", code: 1502, userInfo: [NSLocalizedDescriptionKey: "No upgrade requirement for this building type."])
                    return nil
                }
                for (itemID, requiredQty) in required {
                    let invRef = inventoryRef.document(itemID)
                    let invSnap = try transaction.getDocument(invRef)
                    let qty = invSnap.data()?["quantity"] as? Double ?? 0
                    if qty < requiredQty {
                        let label = UpgradeCatalog.machineUpgradeRequirementLabel(for: buildingType)
                        errorPointer?.pointee = NSError(domain: "BuildingService", code: 1502, userInfo: [NSLocalizedDescriptionKey: "Need \(label). Missing or insufficient: \(itemID)."])
                        return nil
                    }
                    var invData = invSnap.data() ?? [:]
                    invData["quantity"] = qty - requiredQty
                    transaction.setData(invData, forDocument: invRef)
                }
                if isExtractor {
                    var a = (machineData["abundance"] as? Int) ?? 50
                    var s = (machineData["stability"] as? Int) ?? 50
                    a = min(Machine.maxAbundanceStability, a + 2)
                    s = min(Machine.maxAbundanceStability, s + 2)
                    machineData["abundance"] = a
                    machineData["stability"] = s
                } else {
                    var out = (machineData["outputValuePerCycle"] as? Double) ?? Machine.defaultOutputValuePerCycle
                    out = min(Machine.maxOutputValuePerCycle, out + 0.5)
                    machineData["outputValuePerCycle"] = out
                }
                let lvl = (machineData["level"] as? Int) ?? 0
                machineData["level"] = lvl + 1
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
}
