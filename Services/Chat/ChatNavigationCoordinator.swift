//
//  ChatNavigationCoordinator.swift
//  Boardroom Tycoon
//
//  Deep-link from mention banner → Dashboard tab → chat hub → specific room/DM.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ChatNavigationCoordinator: ObservableObject {
    /// Target room after `ChatHubView` is shown (consumed once in hub `onAppear`).
    enum MentionDestination: Equatable {
        case `public`(PublicChatRoom)
        case direct(dmId: String, otherUserId: String)
    }

    @Published private(set) var mentionDestination: MentionDestination?
    /// Incremented to tell the dashboard chat toolbar to push `ChatHubView`.
    @Published private(set) var openChatHubSequence: Int = 0

    /// Tab that hosts the primary chat entry (toolbar bubble).
    static let chatHostTab = MainTabView.Tab.dashboard

    /// Parses mention payload and stores navigation state. Returns false if payload can’t be mapped.
    @discardableResult
    func openChatFromMention(_ payload: ChatMentionBannerController.BannerPayload, currentUserId: String) -> Bool {
        guard let dest = Self.destination(from: payload, currentUserId: currentUserId) else {
            return false
        }
        mentionDestination = dest
        openChatHubSequence += 1
        return true
    }

    /// Called from `ChatHubView.onAppear` to apply a pending mention navigation once.
    func consumeMentionDestination() -> MentionDestination? {
        defer { mentionDestination = nil }
        return mentionDestination
    }

    static func destination(
        from payload: ChatMentionBannerController.BannerPayload,
        currentUserId: String
    ) -> MentionDestination? {
        switch payload.kind {
        case "direct":
            guard let dmId = payload.dmId, !dmId.isEmpty else { return nil }
            let other = payload.dmOtherUserId.flatMap { $0.isEmpty ? nil : $0 }
                ?? otherUserId(inDmDocumentId: dmId, currentUserId: currentUserId)
            guard let other else { return nil }
            return .direct(dmId: dmId, otherUserId: other)
        default:
            guard let rid = payload.publicRoomId, let room = PublicChatRoom(rawValue: rid) else { return nil }
            return .public(room)
        }
    }

    /// `dmId` format: `minUid_maxUid` with `_` separator (UIDs are alphanumeric).
    static func otherUserId(inDmDocumentId dmId: String, currentUserId: String) -> String? {
        let parts = dmId.split(separator: "_", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 else { return nil }
        if parts[0] == currentUserId { return parts[1] }
        if parts[1] == currentUserId { return parts[0] }
        return nil
    }
}
