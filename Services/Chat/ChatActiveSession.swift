//
//  ChatActiveSession.swift
//  Boardroom Tycoon
//
//  Tracks which chat screen is visible so @mention banners can be suppressed in that room.
//

import Foundation
import Combine

@MainActor
final class ChatActiveSession: ObservableObject {
    static let shared = ChatActiveSession()

    enum Focus: Equatable {
        case none
        case publicRoom(id: String)
        case direct(dmId: String)
    }

    @Published private(set) var focus: Focus = .none

    private init() {}

    func enterPublicRoom(_ room: PublicChatRoom) {
        focus = .publicRoom(id: room.rawValue)
    }

    func enterDirect(dmId: String) {
        focus = .direct(dmId: dmId)
    }

    func leaveChat() {
        focus = .none
    }

    func shouldSuppressMentionBanner(publicRoomId: String?) -> Bool {
        guard case .publicRoom(let id) = focus else { return false }
        return publicRoomId == id
    }

    func shouldSuppressMentionBanner(dmId: String?) -> Bool {
        guard case .direct(let active) = focus else { return false }
        guard let dmId else { return false }
        return active == dmId
    }
}
