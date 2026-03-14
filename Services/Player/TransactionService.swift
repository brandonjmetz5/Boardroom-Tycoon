//
//  TransactionService.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation
import FirebaseFirestore

final class TransactionService {
    private let db = Firestore.firestore()

    func fetchTransactions(for userID: String, completion: @escaping (Result<[TransactionRecord], Error>) -> Void) {
        let transactionsRef = db.collection("playerProfiles").document(userID).collection("transactions")

        transactionsRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let transactions: [TransactionRecord] = documents.compactMap { document in
                let data = document.data()

                guard
                    let id = data["id"] as? String,
                    let type = data["type"] as? String,
                    let amount = data["amount"] as? Double,
                    let description = data["description"] as? String,
                    let createdAtTimestamp = data["createdAt"] as? Timestamp
                else {
                    return nil
                }

                return TransactionRecord(
                    id: id,
                    type: type,
                    amount: amount,
                    description: description,
                    createdAt: createdAtTimestamp.dateValue()
                )
            }

            completion(.success(transactions))
        }
    }

    /// Record a transaction (e.g. stock buy/sell). Optional for analytics/history.
    func createTransaction(
        userID: String,
        type: String,
        amount: Double,
        description: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let ref = db.collection("playerProfiles").document(userID).collection("transactions").document()
        let data: [String: Any] = [
            "id": ref.documentID,
            "type": type,
            "amount": amount,
            "description": description,
            "createdAt": Timestamp(date: Date())
        ]
        ref.setData(data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
