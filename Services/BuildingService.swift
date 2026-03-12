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

                let resourceType: ResourceType?
                if let resourceTypeRawValue = data["resourceType"] as? String {
                    resourceType = ResourceType(rawValue: resourceTypeRawValue)
                } else {
                    resourceType = nil
                }

                let abundance = data["abundance"] as? Int
                let stability = data["stability"] as? Int
                let isStarterMine = data["isStarterMine"] as? Bool

                return Building(
                    id: id,
                    name: name,
                    type: type,
                    level: level,
                    capacity: capacity,
                    resourceType: resourceType,
                    abundance: abundance,
                    stability: stability,
                    isStarterMine: isStarterMine
                )
            }

            completion(.success(buildings))
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

                guard var cash = profileSnapshot.data()?["cash"] as? Double,
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
                    "resourceType": "Gold",
                    "abundance": 50,
                    "stability": 55,
                    "isStarterMine": true
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
}
