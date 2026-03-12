//
//  OwnedMineService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation
import FirebaseFirestore

final class OwnedMineService {
    private let db = Firestore.firestore()

    func fetchOwnedMines(for userID: String, completion: @escaping (Result<[Mine], Error>) -> Void) {
        let minesRef = db.collection("playerProfiles").document(userID).collection("ownedMines")

        minesRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let mines: [Mine] = documents.compactMap { document in
                let data = document.data()

                guard
                    let id = data["id"] as? String,
                    let resourceTypeRawValue = data["resourceType"] as? String,
                    let resourceType = ResourceType(rawValue: resourceTypeRawValue),
                    let level = data["level"] as? Int,
                    let abundance = data["abundance"] as? Int,
                    let stability = data["stability"] as? Int,
                    let isStarterMine = data["isStarterMine"] as? Bool
                else {
                    return nil
                }

                return Mine(
                    id: id,
                    resourceType: resourceType,
                    level: level,
                    abundance: abundance,
                    stability: stability,
                    isStarterMine: isStarterMine
                )
            }

            completion(.success(mines))
        }
    }
}
