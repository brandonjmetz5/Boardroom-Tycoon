//
//  ChatMentionTopBannerView.swift
//  Boardroom Tycoon
//
//  Top-of-app mention alert: 5s auto-dismiss with shrinking progress bar; swipe up to dismiss.
//

import SwiftUI

struct ChatMentionTopBannerView: View {
    @ObservedObject var controller: ChatMentionBannerController
    let payload: ChatMentionBannerController.BannerPayload
    /// Opens the correct chat (public room or DM) and dismisses the banner.
    let onOpenMention: () -> Void

    @State private var dragOffset: CGFloat = 0

    private var duration: TimeInterval { ChatMentionBannerController.bannerDisplayDuration }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "at.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Mentioned you")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Tap to open chat")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.accent.opacity(0.9))
                    Text(payload.fromUserId)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)
                    Text(payload.preview)
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Button {
                    controller.dismissActiveBanner(userInitiated: true)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if let start = controller.bannerClockStart {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    let elapsed = context.date.timeIntervalSince(start)
                    let remainingFraction = max(0, min(1, 1 - elapsed / duration))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(AppTheme.border.opacity(0.5))
                                .frame(height: 3)
                            Rectangle()
                                .fill(AppTheme.accent)
                                .frame(width: geo.size.width * remainingFraction, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenMention()
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.surface.opacity(0.96))
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
        )
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let dy = value.translation.height
                    if dy < 0 {
                        dragOffset = dy
                    }
                }
                .onEnded { value in
                    let dy = value.translation.height
                    let predicted = value.predictedEndTranslation.height
                    if dy < -56 || predicted < -100 {
                        controller.dismissActiveBanner(userInitiated: true)
                    }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mention from \(payload.fromUserId). \(payload.preview)")
        .accessibilityHint("Tap to open the chat where you were mentioned.")
    }
}
