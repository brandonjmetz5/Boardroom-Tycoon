//
//  ChatToolbarModifier.swift
//  Boardroom Tycoon
//
//  Chat bubble in the trailing toolbar; pushes the chat hub on the tab’s NavigationStack.
//

import SwiftUI
import Combine

struct ChatToolbarModifier: ViewModifier {
    let userID: String
    /// Which tab owns this `NavigationStack`; only the chat host tab reacts to mention deep links.
    let hostTab: MainTabView.Tab

    @EnvironmentObject private var chatNav: ChatNavigationCoordinator
    @State private var showChats = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showChats = true
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                    }
                    .accessibilityLabel("Chats")
                }
            }
            .navigationDestination(isPresented: $showChats) {
                ChatHubView(userID: userID)
            }
            .onChange(of: chatNav.openChatHubSequence) { _, _ in
                guard hostTab == ChatNavigationCoordinator.chatHostTab else { return }
                showChats = true
            }
    }
}

extension View {
    /// Adds the chat entry point (top-right). Use on main tabs except Profile.
    func chatToolbar(userID: String, hostTab: MainTabView.Tab) -> some View {
        modifier(ChatToolbarModifier(userID: userID, hostTab: hostTab))
    }
}
