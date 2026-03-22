//
//  ChatRoomViewModel.swift
//  Boardroom Tycoon
//

import Foundation
import Combine
import FirebaseFirestore

enum ChatRoomMode: Hashable {
    case `public`(PublicChatRoom)
    case direct(dmId: String, otherUserId: String)
}

@MainActor
final class ChatRoomViewModel: ObservableObject {
    let userID: String
    let mode: ChatRoomMode

    @Published private(set) var messages: [ChatMessage] = []
    @Published var draftText: String = ""
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?

    private let chatService = ChatService()
    private var listener: ListenerRegistration?
    private var visibilityTick: AnyCancellable?

    init(userID: String, mode: ChatRoomMode) {
        self.userID = userID
        self.mode = mode
    }

    deinit {
        listener?.remove()
        visibilityTick?.cancel()
    }

    var navigationTitle: String {
        switch mode {
        case .public(let room):
            return room.title
        case .direct(_, let otherUserId):
            return otherUserId
        }
    }

    func startListening() {
        listener?.remove()
        visibilityTick?.cancel()
        visibilityTick = nil
        errorMessage = nil

        switch mode {
        case .public(let room):
            // Sliding 24h window if the user keeps a public room open (query cutoff is fixed at attach time).
            visibilityTick = Timer.publish(every: 120, tolerance: 15, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.trimStaleDisplayedMessages()
                }
            listener = chatService.listenPublicMessages(room: room) { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    switch result {
                    case .success(let msgs):
                        self.messages = Self.messagesChronologicalWithinVisibleWindow(msgs)
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        case .direct(let dmId, _):
            listener = chatService.listenDirectMessages(dmId: dmId) { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    switch result {
                    case .success(let msgs):
                        self.messages = msgs.sorted { $0.createdAt < $1.createdAt }
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        visibilityTick?.cancel()
        visibilityTick = nil
    }

    private func trimStaleDisplayedMessages() {
        let cutoff = Date().addingTimeInterval(-ChatService.visibleMessageMaxAge)
        messages = messages.filter { $0.createdAt >= cutoff }
    }

    private static func messagesChronologicalWithinVisibleWindow(_ msgs: [ChatMessage]) -> [ChatMessage] {
        let cutoff = Date().addingTimeInterval(-ChatService.visibleMessageMaxAge)
        return msgs
            .filter { $0.createdAt >= cutoff }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func sendMessage() {
        let text = draftText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSending = true
        errorMessage = nil

        switch mode {
        case .public(let room):
            chatService.sendPublicMessage(room: room, senderId: userID, text: text) { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isSending = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        self.draftText = ""
                    }
                }
            }
        case .direct(let dmId, let otherUserId):
            chatService.sendDirectMessage(
                dmId: dmId,
                senderId: userID,
                otherUserId: otherUserId,
                text: text
            ) { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isSending = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        self.draftText = ""
                    }
                }
            }
        }
    }
}
