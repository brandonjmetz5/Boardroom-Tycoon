//
//  ChatHubView.swift
//  Boardroom Tycoon
//
//  Public rooms + list of direct threads; start new DM by peer UID.
//

import SwiftUI

struct ChatHubView: View {
    let userID: String

    @EnvironmentObject private var chatNav: ChatNavigationCoordinator
    @StateObject private var viewModel: ChatHubViewModel
    /// Pushes a room on the same NavigationStack as this hub (no nested stack).
    @State private var activeRoom: ChatRoute?
    @State private var showNewDirect = false
    @State private var newPeerId = ""

    init(userID: String) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: ChatHubViewModel(userID: userID))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            LinearGradient(
                colors: [AppTheme.surface.opacity(0.12), Color.clear, AppTheme.surface.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    commandHeaderRail
                    ChatRail(title: "Public channels", systemImage: "number.square.fill") {
                        VStack(spacing: 10) {
                            ForEach(PublicChatRoom.allCases) { room in
                                ChatHubDestinationRow(
                                    title: room.title,
                                    subtitle: room.subtitle,
                                    systemImage: systemImage(for: room)
                                ) {
                                    activeRoom = .public(room)
                                }
                            }
                        }
                    }
                    ChatRail(title: "Direct messages", systemImage: "person.2.fill") {
                        if viewModel.directThreads.isEmpty {
                            Text("No direct messages yet. Tap the compose button to start one.")
                                .font(AppTheme.caption())
                                .foregroundStyle(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(viewModel.directThreads) { thread in
                                    ChatHubDestinationRow(
                                        title: thread.otherUserId,
                                        subtitle: thread.lastMessagePreview.isEmpty
                                            ? "Tap to open conversation"
                                            : thread.lastMessagePreview,
                                        systemImage: "person.fill"
                                    ) {
                                        activeRoom = .direct(dmId: thread.id, otherUserId: thread.otherUserId)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Communications")
                    .font(AppTheme.titleMedium())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newPeerId = ""
                    showNewDirect = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .accessibilityLabel("New direct message")
            }
        }
        .navigationDestination(item: $activeRoom) { route in
            switch route {
            case .public(let room):
                ChatRoomView(userID: userID, mode: .public(room))
            case .direct(let dmId, let other):
                ChatRoomView(userID: userID, mode: .direct(dmId: dmId, otherUserId: other))
            }
        }
        .sheet(isPresented: $showNewDirect) {
            NewDirectChatSheet(
                currentUserId: userID,
                peerId: $newPeerId,
                onOpen: { dmId, other in
                    showNewDirect = false
                    activeRoom = .direct(dmId: dmId, otherUserId: other)
                }
            )
        }
        .onAppear {
            viewModel.startListening()
            if let dest = chatNav.consumeMentionDestination() {
                switch dest {
                case .public(let room):
                    activeRoom = .public(room)
                case .direct(let dmId, let other):
                    activeRoom = .direct(dmId: dmId, otherUserId: other)
                }
            }
        }
        .onDisappear { viewModel.stopListening() }
    }

    private var commandHeaderRail: some View {
        ChatRail(title: "Communications desk", systemImage: "bubble.left.and.bubble.right.fill", tone: .priority) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Executive messaging")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Public channels and encrypted direct threads. Display names ship in a future build.")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.chipReady)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.chipReady.opacity(0.16)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.chipReady.opacity(0.45), lineWidth: 1))
            }
        }
    }

    private func systemImage(for room: PublicChatRoom) -> String {
        switch room {
        case .general: return "bubble.left.and.bubble.right.fill"
        case .sales: return "cart.fill"
        case .help: return "lifepreserver.fill"
        }
    }
}

private enum ChatRoute: Hashable {
    case `public`(PublicChatRoom)
    case direct(dmId: String, otherUserId: String)
}

private enum ChatRailTone {
    case normal
    case priority
}

/// Matches MarketRail / Inventory rail styling.
private struct ChatRail<Content: View>: View {
    let title: String
    let systemImage: String
    var tone: ChatRailTone
    private let content: Content

    init(
        title: String,
        systemImage: String,
        tone: ChatRailTone = .normal,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tone == .priority ? AppTheme.accent : AppTheme.textSecondary)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                Rectangle().fill(AppTheme.border).frame(height: 1)
            }
            content
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surface.opacity(0.82)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tone == .priority ? AppTheme.accent.opacity(0.32) : AppTheme.border.opacity(0.95), lineWidth: 1)
        )
    }
}

/// Tappable row styled like `MarketHubView` hub cards.
private struct ChatHubDestinationRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.cardBackgroundAlt.opacity(0.95))
                        .frame(width: 48, height: 48)
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
        }
        .buttonStyle(.plain)
    }
}

private struct NewDirectChatSheet: View {
    let currentUserId: String
    @Binding var peerId: String
    var onOpen: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    private var trimmedPeer: String {
        peerId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validationMessage: String? {
        if trimmedPeer.isEmpty { return nil }
        if trimmedPeer == currentUserId {
            return "Enter another player’s user ID, not your own."
        }
        return nil
    }

    private var canOpen: Bool {
        !trimmedPeer.isEmpty && trimmedPeer != currentUserId
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                LinearGradient(
                    colors: [AppTheme.surface.opacity(0.12), Color.clear, AppTheme.surface.opacity(0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ChatRail(title: "Peer identifier", systemImage: "person.text.rectangle.fill", tone: .priority) {
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Other player’s user ID", text: $peerId)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focused)
                                    .font(AppTheme.body())
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .tint(AppTheme.accent)
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(AppTheme.surfaceAlt.opacity(0.58))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(AppTheme.border.opacity(0.95), lineWidth: 1)
                                    )

                                Text("Until display names ship, paste the other player’s Firebase Auth UID from Profile.")
                                    .font(AppTheme.caption())
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if let validationMessage {
                            ChatRail(title: "Notice", systemImage: "exclamationmark.triangle.fill", tone: .priority) {
                                Text(validationMessage)
                                    .font(AppTheme.caption())
                                    .foregroundStyle(AppTheme.textError)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New direct message")
                        .font(AppTheme.titleMedium())
                        .foregroundStyle(AppTheme.textPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Open") {
                        let other = trimmedPeer
                        let dmId = ChatService.directChatDocumentId(between: currentUserId, and: other)
                        onOpen(dmId, other)
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(canOpen ? AppTheme.accent : AppTheme.textMuted)
                    .disabled(!canOpen)
                }
            }
            .onAppear { focused = true }
        }
    }
}

#Preview {
    NavigationStack {
        ChatHubView(userID: "preview-user")
            .environmentObject(ChatNavigationCoordinator())
    }
}
