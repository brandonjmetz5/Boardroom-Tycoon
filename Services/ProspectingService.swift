//
//  ProspectingService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class ProspectingService {
    private let db = Firestore.firestore()

    func fetchProspectingJobs(for userID: String, completion: @escaping (Result<[ProspectingJob], Error>) -> Void) {
        let jobsRef = db.collection("playerProfiles").document(userID).collection("prospectingJobs")

        jobsRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let jobs: [ProspectingJob] = documents.compactMap { document in
                let data = document.data()

                guard
                    let id = data["id"] as? String,
                    let resourceTypeRawValue = data["resourceType"] as? String,
                    let resourceType = ResourceType(rawValue: resourceTypeRawValue),
                    let startedAtTimestamp = data["startedAt"] as? Timestamp,
                    let endsAtTimestamp = data["endsAt"] as? Timestamp,
                    let isComplete = data["isComplete"] as? Bool
                else {
                    return nil
                }

                return ProspectingJob(
                    id: id,
                    resourceType: resourceType,
                    startedAt: startedAtTimestamp.dateValue(),
                    endsAt: endsAtTimestamp.dateValue(),
                    isComplete: isComplete
                )
            }

            completion(.success(jobs))
        }
    }
}
