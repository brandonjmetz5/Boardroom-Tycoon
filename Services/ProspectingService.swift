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
                    let isComplete = data["isComplete"] as? Bool,
                    let isRevealed = data["isRevealed"] as? Bool
                else {
                    return nil
                }

                let revealedAbundance = data["revealedAbundance"] as? Int
                let revealedStability = data["revealedStability"] as? Int

                return ProspectingJob(
                    id: id,
                    resourceType: resourceType,
                    startedAt: startedAtTimestamp.dateValue(),
                    endsAt: endsAtTimestamp.dateValue(),
                    isComplete: isComplete,
                    isRevealed: isRevealed,
                    revealedAbundance: revealedAbundance,
                    revealedStability: revealedStability
                )
            }

            completion(.success(jobs))
        }
    }

    func startProspecting(for userID: String, resourceType: ResourceType, completion: @escaping (Result<Void, Error>) -> Void) {
        let profileRef = db.collection("playerProfiles").document(userID)
        let buildingsRef = profileRef.collection("buildings")
        let jobsRef = profileRef.collection("prospectingJobs")

        let prospectingCost = 750.0

        buildingsRef.getDocuments { buildingSnapshot, buildingError in
            if let buildingError = buildingError {
                completion(.failure(buildingError))
                return
            }

            jobsRef.getDocuments { jobSnapshot, jobError in
                if let jobError = jobError {
                    completion(.failure(jobError))
                    return
                }

                let currentBuildingCount = buildingSnapshot?.documents.count ?? 0

                let activeJobCount = jobSnapshot?.documents.filter { document in
                    let data = document.data()
                    let isComplete = data["isComplete"] as? Bool ?? false
                    return !isComplete
                }.count ?? 0

                self.db.runTransaction({ transaction, errorPointer in
                    do {
                        let profileSnapshot = try transaction.getDocument(profileRef)

                        guard
                            let profileData = profileSnapshot.data(),
                            let currentCash = profileData["cash"] as? Double,
                            let buildingSlotCount = profileData["buildingSlotCount"] as? Int
                        else {
                            let error = NSError(
                                domain: "ProspectingService",
                                code: 3001,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid player profile data."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        if activeJobCount > 0 {
                            let error = NSError(
                                domain: "ProspectingService",
                                code: 3002,
                                userInfo: [NSLocalizedDescriptionKey: "Only one active prospecting job is allowed."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        let usedSlots = currentBuildingCount + activeJobCount
                        if usedSlots >= buildingSlotCount {
                            let error = NSError(
                                domain: "ProspectingService",
                                code: 3003,
                                userInfo: [NSLocalizedDescriptionKey: "No available building slots for prospecting."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        if currentCash < prospectingCost {
                            let error = NSError(
                                domain: "ProspectingService",
                                code: 3004,
                                userInfo: [NSLocalizedDescriptionKey: "Not enough cash to start prospecting."]
                            )
                            errorPointer?.pointee = error
                            return nil
                        }

                        let jobRef = jobsRef.document("prospecting-\(UUID().uuidString)")
                        let startedAt = Date()
                        let endsAt = startedAt.addingTimeInterval(10) // temporary 10 seconds for testing
                        // let endsAt = startedAt.addingTimeInterval(60 * 60 * 4)

                        let jobData: [String: Any] = [
                            "id": jobRef.documentID,
                            "resourceType": resourceType.rawValue,
                            "startedAt": Timestamp(date: startedAt),
                            "endsAt": Timestamp(date: endsAt),
                            "isComplete": false,
                            "isRevealed": false
                        ]

                        transaction.setData(jobData, forDocument: jobRef)
                        transaction.updateData([
                            "cash": currentCash - prospectingCost
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
    
    func revealProspectingJob(for userID: String, jobID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let jobRef = db.collection("playerProfiles")
            .document(userID)
            .collection("prospectingJobs")
            .document(jobID)

        db.runTransaction({ transaction, errorPointer in
            do {
                let jobSnapshot = try transaction.getDocument(jobRef)

                guard
                    let jobData = jobSnapshot.data(),
                    let endsAtTimestamp = jobData["endsAt"] as? Timestamp,
                    let isComplete = jobData["isComplete"] as? Bool,
                    let isRevealed = jobData["isRevealed"] as? Bool
                else {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3010,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid prospecting job data."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if isComplete {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3011,
                        userInfo: [NSLocalizedDescriptionKey: "This prospecting job is already completed."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if isRevealed {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3012,
                        userInfo: [NSLocalizedDescriptionKey: "This prospecting job has already been revealed."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                if endsAtTimestamp.dateValue() > Date() {
                    let error = NSError(
                        domain: "ProspectingService",
                        code: 3013,
                        userInfo: [NSLocalizedDescriptionKey: "Prospecting is not finished yet."]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let abundance = Int.random(in: 50...100)
                let stability = Int.random(in: 50...100)

                transaction.updateData([
                    "isRevealed": true,
                    "revealedAbundance": abundance,
                    "revealedStability": stability
                ], forDocument: jobRef)

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
