//
//  PlayerProfileService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation
import FirebaseFirestore

final class PlayerProfileService {
    private let db = Firestore.firestore()

    func createPlayerProfileIfNeeded(for profile: PlayerProfile, completion: @escaping (Result<Void, Error>) -> Void) {
        let docRef = db.collection("playerProfiles").document(profile.id)

        docRef.getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let document = document, document.exists {
                completion(.success(()))
                return
            }

            let data: [String: Any] = [
                "id": profile.id,
                "cash": profile.cash,
                "level": profile.level,
                "xp": profile.xp,
                "buildingSlotCount": profile.buildingSlotCount,
                "starterMineClaimed": profile.starterMineClaimed,
                "researchPoints": profile.researchPoints,
                "createdAt": Timestamp(date: profile.createdAt)
            ]

            docRef.setData(data) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    func fetchPlayerProfile(for uid: String, completion: @escaping (Result<PlayerProfile, Error>) -> Void) {
        let docRef = db.collection("playerProfiles").document(uid)

        docRef.getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard
                let document = document,
                let data = document.data()
            else {
                completion(.failure(NSError(
                    domain: "PlayerProfileService",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Player profile not found."]
                )))
                return
            }

            guard
                let id = data["id"] as? String,
                let cash = data["cash"] as? Double,
                let level = data["level"] as? Int,
                let xp = data["xp"] as? Int,
                let buildingSlotCount = data["buildingSlotCount"] as? Int,
                let starterMineClaimed = data["starterMineClaimed"] as? Bool,
                let createdAtTimestamp = data["createdAt"] as? Timestamp
            else {
                completion(.failure(NSError(
                    domain: "PlayerProfileService",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid player profile data."]
                )))
                return
            }

            let researchPoints = data["researchPoints"] as? Int ?? 0

            let profile = PlayerProfile(
                id: id,
                cash: cash,
                level: level,
                xp: xp,
                buildingSlotCount: buildingSlotCount,
                starterMineClaimed: starterMineClaimed,
                researchPoints: researchPoints,
                createdAt: createdAtTimestamp.dateValue()
            )

            completion(.success(profile))
        }
    }
}
