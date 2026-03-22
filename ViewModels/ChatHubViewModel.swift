//
//  ChatHubViewModel.swift
//  Boardroom Tycoon
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class ChatHubViewModel: ObservableObject {
    let userID: String

    @Published private(set) var directThreads: [DirectChatThread] = []
    @Published private(set) var errorMessage: String?

    private let chatService = ChatService()
    private var listener: ListenerRegistration?

    init(userID: String) {
        self.userID = userID
    }

    deinit {
        listener?.remove()
    }

    func startListening() {
        listener?.remove()
        errorMessage = nil
        listener = chatService.listenDirectThreads(for: userID) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let threads):
                    self.directThreads = threads
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
