//
//  ChatFormattedMessageView.swift
//  Boardroom Tycoon
//
//  Renders chat text with #Resource tags replaced by inline catalog icons.
//

import SwiftUI

// MARK: - Public view

struct ChatFormattedMessageView: View {
    let text: String
    var maxLineWidth: CGFloat = 260
    var textAlignment: TextAlignment = .leading

    var body: some View {
        let segments = ChatResourceTagResolver.parseMessageSegments(text)
        Group {
            if segments.isEmpty {
                Text(" ")
                    .font(AppTheme.body())
            } else if segments.count == 1, case .text(let only) = segments[0] {
                Text(only)
                    .font(AppTheme.body())
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(textAlignment)
            } else {
                FlowLayout(spacing: 4, lineSpacing: 3) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        switch segment {
                        case .text(let chunk):
                            Text(chunk)
                                .font(AppTheme.body())
                                .foregroundStyle(AppTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        case .resource(let item):
                            ResourceTagIconView(item: item, size: 22)
                        }
                    }
                }
                .frame(maxWidth: maxLineWidth, alignment: .leading)
            }
        }
    }
}

// MARK: - Inline icon

private struct ResourceTagIconView: View {
    let item: Item
    var size: CGFloat = 22

    var body: some View {
        Group {
            if let asset = ItemResourceIconAsset.assetName(forItemDisplayName: item.name) {
                Image(asset)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.border.opacity(0.6), lineWidth: 1))
            } else {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.22))
                        .frame(width: size, height: size)
                    Text(String(item.name.prefix(1)).uppercased())
                        .font(.system(size: max(9, size * 0.38), weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .accessibilityLabel(item.name)
        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] * 0.72 }
    }
}

// MARK: - Flow layout (wrapping row for text + icons)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 3

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (i, subview) in subviews.enumerated() {
            let frame = result.frames[i]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = min(proposal.width ?? 280, 400)
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let roomOnLine = max(1, maxWidth - x)
            var childSize = subview.sizeThatFits(ProposedViewSize(width: roomOnLine, height: nil))

            if x > 0, x + childSize.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
                childSize = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            }

            if x == 0, childSize.width > maxWidth {
                childSize = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            }

            let frame = CGRect(x: x, y: y, width: min(childSize.width, maxWidth), height: childSize.height)
            frames.append(frame)
            lineHeight = max(lineHeight, childSize.height)
            x += frame.width + spacing
        }

        let totalHeight = y + lineHeight
        let usedWidth = frames.map(\.maxX).max() ?? 0
        return (CGSize(width: min(usedWidth, maxWidth), height: totalHeight), frames)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        ChatFormattedMessageView(text: "Selling 100 units of #rawgold today!")
        ChatFormattedMessageView(text: "#RawGold #Steel — bundle deal")
        ChatFormattedMessageView(text: "No tags here, just text.")
    }
    .padding()
    .background(AppTheme.background)
}
