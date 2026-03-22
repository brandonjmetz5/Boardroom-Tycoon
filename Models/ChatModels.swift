//
//  ChatModels.swift
//  Boardroom Tycoon
//
//  Firestore-backed chat: public rooms + direct threads.
//

import Foundation
import FirebaseFirestore

/// Fixed IDs under `publicChats/{id}/messages`.
enum PublicChatRoom: String, CaseIterable, Identifiable, Hashable {
    case general = "general"
    case sales = "sales"
    case help = "help"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .sales: return "Sales"
        case .help: return "Help"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Community discussion"
        case .sales: return "Trading & deals"
        case .help: return "Questions & support"
        }
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let senderId: String
    let text: String
    let createdAt: Date

    init(id: String, senderId: String, text: String, createdAt: Date) {
        self.id = id
        self.senderId = senderId
        self.text = text
        self.createdAt = createdAt
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let senderId = data["senderId"] as? String,
              let text = data["text"] as? String else { return nil }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.init(id: document.documentID, senderId: senderId, text: text, createdAt: createdAt)
    }
}

struct DirectChatThread: Identifiable, Equatable {
    /// Firestore document ID for `directChats/{id}`.
    let id: String
    let otherUserId: String
    let lastMessagePreview: String
    let updatedAt: Date

    init?(document: DocumentSnapshot, currentUserId: String) {
        guard let data = document.data(),
              let ids = data["participantIds"] as? [String],
              ids.contains(currentUserId),
              let other = ids.first(where: { $0 != currentUserId })
        else { return nil }

        self.id = document.documentID
        self.otherUserId = other
        self.lastMessagePreview = (data["lastMessageText"] as? String) ?? ""
        if let ts = data["updatedAt"] as? Timestamp {
            self.updatedAt = ts.dateValue()
        } else {
            self.updatedAt = .distantPast
        }
    }
}
