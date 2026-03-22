//
//  ChatRoomView.swift
//  Boardroom Tycoon
//

import SwiftUI

struct ChatRoomView: View {
    @StateObject private var viewModel: ChatRoomViewModel
    @FocusState private var composerFocused: Bool

    init(userID: String, mode: ChatRoomMode) {
        _viewModel = StateObject(wrappedValue: ChatRoomViewModel(userID: userID, mode: mode))
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

            VStack(spacing: 0) {
                if let err = viewModel.errorMessage, !err.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.textError)
                        Text(err)
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textError)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.chipNegative.opacity(0.12)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.chipNegative.opacity(0.35), lineWidth: 1)
                    )
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 8)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                ChatMessageRow(message: message, isOwn: message.senderId == viewModel.userID)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, AppTheme.horizontalPadding)
                        .padding(.vertical, 14)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let last = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = viewModel.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                composer
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(roomToolbarTitle)
                    .font(AppTheme.titleSmall())
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
            }
        }
        .onAppear {
            switch viewModel.mode {
            case .public(let room):
                ChatActiveSession.shared.enterPublicRoom(room)
            case .direct(let dmId, _):
                ChatActiveSession.shared.enterDirect(dmId: dmId)
            }
            viewModel.startListening()
        }
        .onDisappear {
            ChatActiveSession.shared.leaveChat()
            viewModel.stopListening()
        }
    }

    private var roomToolbarTitle: String {
        switch viewModel.mode {
        case .public(let room):
            return room.title
        case .direct:
            return viewModel.navigationTitle
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message", text: $viewModel.draftText, axis: .vertical)
                .lineLimit(1...5)
                .focused($composerFocused)
                .font(AppTheme.body())
                .foregroundStyle(AppTheme.textPrimary)
                .tint(AppTheme.accent)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.surfaceAlt.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.95), lineWidth: 1)
                )

            Button {
                viewModel.sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        viewModel.isSending || viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AppTheme.textMuted
                            : AppTheme.accent
                    )
            }
            .disabled(viewModel.isSending || viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, AppTheme.horizontalPadding)
        .padding(.vertical, 12)
        .background(
            AppTheme.surface.opacity(0.94)
                .shadow(color: .black.opacity(0.25), radius: 12, y: -4)
        )
    }
}

private struct ChatMessageRow: View {
    let message: ChatMessage
    let isOwn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isOwn { Spacer(minLength: 36) }

            if !isOwn {
                ZStack {
                    Circle()
                        .fill(AppTheme.cardBackgroundAlt.opacity(0.95))
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
                Text(message.senderId)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
                ChatFormattedMessageView(
                    text: message.text,
                    maxLineWidth: 260,
                    textAlignment: isOwn ? .trailing : .leading
                )
                    .multilineTextAlignment(isOwn ? .trailing : .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                isOwn
                                    ? AppTheme.accent.opacity(0.22)
                                    : AppTheme.surface.opacity(0.88)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isOwn ? AppTheme.accent.opacity(0.35) : AppTheme.border.opacity(0.9),
                                lineWidth: 1
                            )
                    )
                Text(message.createdAt.formattedChatTimeOnly())
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textMuted)
            }

            if !isOwn { Spacer(minLength: 36) }

            if isOwn {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.28))
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
    }
}

#Preview {
    NavigationStack {
        ChatRoomView(userID: "me", mode: .public(.general))
    }
}
