//
//  ChatService.swift
//  Boardroom Tycoon
//
//  Firestore layout (see CHAT_FIRESTORE.md):
//  - publicChats/{general|sales|help}/messages/{msgId}
//  - directChats/{uid_uid}/messages/{msgId}  with parent fields participantIds, lastMessageText, updatedAt
//

import Foundation
import FirebaseFirestore

final class ChatService {
    private let db = Firestore.firestore()

    /// Public channels only: load messages from roughly the last 24 hours (matches `purgePublicChatMessages`).
    /// Direct messages use full thread history (no max age).
    static let visibleMessageMaxAge: TimeInterval = 24 * 60 * 60

    // MARK: - Paths

    private func publicMessagesCollection(_ room: PublicChatRoom) -> CollectionReference {
        db.collection("publicChats").document(room.rawValue).collection("messages")
    }

    private func directChatRef(_ dmId: String) -> DocumentReference {
        db.collection("directChats").document(dmId)
    }

    private func directMessagesCollection(_ dmId: String) -> CollectionReference {
        directChatRef(dmId).collection("messages")
    }

    /// Stable DM document id from two Firebase Auth UIDs (sorted).
    static func directChatDocumentId(between userA: String, and userB: String) -> String {
        let sorted = [userA, userB].sorted()
        return "\(sorted[0])_\(sorted[1])"
    }

    // MARK: - Public rooms

    private func messageVisibilityCutoff() -> Timestamp {
        Timestamp(date: Date().addingTimeInterval(-Self.visibleMessageMaxAge))
    }

    func listenPublicMessages(
        room: PublicChatRoom,
        limit: Int = 100,
        onUpdate: @escaping (Result<[ChatMessage], Error>) -> Void
    ) -> ListenerRegistration {
        publicMessagesCollection(room)
            .whereField("createdAt", isGreaterThanOrEqualTo: messageVisibilityCutoff())
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onUpdate(.failure(error))
                    return
                }
                guard let snapshot else {
                    onUpdate(.success([]))
                    return
                }
                let messages = snapshot.documents.compactMap { ChatMessage(document: $0) }
                onUpdate(.success(messages))
            }
    }

    func sendPublicMessage(
        room: PublicChatRoom,
        senderId: String,
        text: String,
        completion: @escaping (Error?) -> Void
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(nil)
            return
        }

        let mentioned = ChatMentionParser.mentionedUserIds(in: trimmed, excluding: senderId)
        var data: [String: Any] = [
            "senderId": senderId,
            "text": trimmed,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if !mentioned.isEmpty {
            data["mentionedUserIds"] = mentioned
        }

        let batch = db.batch()
        let msgRef = publicMessagesCollection(room).document()
        batch.setData(data, forDocument: msgRef)

        for uid in mentioned {
            let mentionRef = db.collection("chatMentions").document()
            batch.setData(
                [
                    "targetUserId": uid,
                    "fromUserId": senderId,
                    "previewText": String(trimmed.prefix(120)),
                    "kind": "public",
                    "publicRoomId": room.rawValue,
                    "createdAt": FieldValue.serverTimestamp(),
                    "consumed": false
                ],
                forDocument: mentionRef
            )
        }

        batch.commit(completion: completion)
    }

    // MARK: - Direct threads list

    func listenDirectThreads(
        for userId: String,
        onUpdate: @escaping (Result<[DirectChatThread], Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("directChats")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onUpdate(.failure(error))
                    return
                }
                guard let snapshot else {
                    onUpdate(.success([]))
                    return
                }
                let threads = snapshot.documents.compactMap { DirectChatThread(document: $0, currentUserId: userId) }
                onUpdate(.success(threads))
            }
    }

    // MARK: - Direct messages

    /// Full history for this DM thread (no time filter). One subcollection per pair, so cardinality stays bounded.
    func listenDirectMessages(
        dmId: String,
        onUpdate: @escaping (Result<[ChatMessage], Error>) -> Void
    ) -> ListenerRegistration {
        directMessagesCollection(dmId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onUpdate(.failure(error))
                    return
                }
                guard let snapshot else {
                    onUpdate(.success([]))
                    return
                }
                let messages = snapshot.documents.compactMap { ChatMessage(document: $0) }
                onUpdate(.success(messages))
            }
    }

    func sendDirectMessage(
        dmId: String,
        senderId: String,
        otherUserId: String,
        text: String,
        completion: @escaping (Error?) -> Void
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(nil)
            return
        }

        let mentioned = ChatMentionParser.mentionedUserIds(in: trimmed, excluding: senderId)
        var msgData: [String: Any] = [
            "senderId": senderId,
            "text": trimmed,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if !mentioned.isEmpty {
            msgData["mentionedUserIds"] = mentioned
        }

        let batch = db.batch()
        let msgRef = directMessagesCollection(dmId).document()
        batch.setData(msgData, forDocument: msgRef)

        let chatRef = directChatRef(dmId)
        batch.setData(
            [
                "participantIds": [senderId, otherUserId],
                "lastMessageText": String(trimmed.prefix(200)),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            forDocument: chatRef,
            merge: true
        )

        for uid in mentioned {
            let mentionRef = db.collection("chatMentions").document()
            batch.setData(
                [
                    "targetUserId": uid,
                    "fromUserId": senderId,
                    "previewText": String(trimmed.prefix(120)),
                    "kind": "direct",
                    "dmId": dmId,
                    "dmOtherUserId": otherUserId,
                    "createdAt": FieldValue.serverTimestamp(),
                    "consumed": false
                ],
                forDocument: mentionRef
            )
        }

        batch.commit(completion: completion)
    }
}
