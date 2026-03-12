//
//  WorldStateService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class WorldStateService {
    private let db = Firestore.firestore()

    func fetchWorldState(completion: @escaping (Result<WorldState, Error>) -> Void) {
        let worldStateRef = db.collection("worldState").document("global")

        worldStateRef.getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard
                let document = document,
                let data = document.data(),
                let starterMinePrice = data["starterMinePrice"] as? Double,
                let buildingSlotsPerTenLevels = data["buildingSlotsPerTenLevels"] as? Int,
                let prospectingEnabled = data["prospectingEnabled"] as? Bool
            else {
                completion(.failure(NSError(
                    domain: "WorldStateService",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "World state not found or invalid."]
                )))
                return
            }

            let worldState = WorldState(
                starterMinePrice: starterMinePrice,
                buildingSlotsPerTenLevels: buildingSlotsPerTenLevels,
                prospectingEnabled: prospectingEnabled
            )

            completion(.success(worldState))
        }
    }
}
