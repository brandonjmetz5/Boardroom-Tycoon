//
//  NotificationService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class NotificationService {
    private let db = Firestore.firestore()

    func fetchNotifications(for userID: String, completion: @escaping (Result<[AppNotification], Error>) -> Void) {
        let notificationsRef = db.collection("playerProfiles").document(userID).collection("notifications")

        notificationsRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let notifications: [AppNotification] = documents.compactMap { document in
                let data = document.data()

                guard
                    let id = data["id"] as? String,
                    let title = data["title"] as? String,
                    let message = data["message"] as? String,
                    let createdAtTimestamp = data["createdAt"] as? Timestamp,
                    let isRead = data["isRead"] as? Bool
                else {
                    return nil
                }

                return AppNotification(
                    id: id,
                    title: title,
                    message: message,
                    createdAt: createdAtTimestamp.dateValue(),
                    isRead: isRead
                )
            }

            completion(.success(notifications))
        }
    }
}
