//
//  ResourceQualityService.swift
//  Boardroom Tycoon
//
//  Per-player resource quality levels and research point progress.
//

import Foundation
import FirebaseFirestore

final class ResourceQualityService {
    private let db = Firestore.firestore()

    private func qualitiesRef(for userID: String) -> CollectionReference {
        db.collection("playerProfiles").document(userID).collection("resourceQualities")
    }

    func fetchQualities(for userID: String, completion: @escaping (Result<[ResourceQuality], Error>) -> Void) {
        qualitiesRef(for: userID).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            let qualities: [ResourceQuality] = documents.compactMap { doc in
                let data = doc.data()
                guard let id = data["id"] as? String,
                      let level = data["qualityLevel"] as? Int,
                      let progress = data["currentResearchPoints"] as? Int else {
                    return nil
                }
                return ResourceQuality(id: id, qualityLevel: level, currentResearchPoints: progress)
            }
            completion(.success(qualities))
        }
    }

    /// Increment research points for a specific resource and advance level if threshold reached.
    func addResearchPoints(for userID: String, itemID: String, points: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let qualityRef = qualitiesRef(for: userID).document(itemID)

        db.runTransaction({ transaction, errorPointer in
            do {
                let profileSnap = try transaction.getDocument(profileRef)
                let qualitySnap = try transaction.getDocument(qualityRef)

                let profileData = profileSnap.data() ?? [:]
                let currentPool = profileData["researchPoints"] as? Int ?? 0
                guard currentPool >= points else {
                    errorPointer?.pointee = NSError(
                        domain: "ResourceQualityService",
                        code: 5101,
                        userInfo: [NSLocalizedDescriptionKey: "Not enough research points."]
                    )
                    return nil
                }

                var level = qualitySnap.data()?["qualityLevel"] as? Int ?? 1
                var progress = qualitySnap.data()?["currentResearchPoints"] as? Int ?? 0
                progress += points

                let required = Self.requiredResearchPoints(forLevel: level)
                if progress >= required {
                    progress -= required
                    level += 1
                }

                transaction.updateData([
                    "researchPoints": currentPool - points
                ], forDocument: profileRef)

                transaction.setData([
                    "id": itemID,
                    "qualityLevel": level,
                    "currentResearchPoints": progress
                ], forDocument: qualityRef, merge: true)

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

    /// Quadratic cost curve: base * level^2, so higher levels require many more points.
    static func requiredResearchPoints(forLevel level: Int) -> Int {
        let base = 100
        return base * level * level
    }
}

