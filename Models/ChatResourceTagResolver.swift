//
//  ChatResourceTagResolver.swift
//  Boardroom Tycoon
//
//  Parses #tags in chat and maps them to MarketCatalog items (e.g. #RawGold, #rawgold, #raw-gold).
//

import Foundation

enum ChatMessageSegment: Hashable {
    case text(String)
    case resource(Item)
}

enum ChatResourceTagResolver {
    private static let hashtagPattern = try! NSRegularExpression(
        pattern: #"#([A-Za-z0-9_-]+)"#,
        options: []
    )

    /// Split message into plain text and resolved tradeable items. Unknown #tags stay as plain text (including `#`).
    static func parseMessageSegments(_ raw: String) -> [ChatMessageSegment] {
        let ns = raw as NSString
        let full = NSRange(location: 0, length: ns.length)
        let matches = hashtagPattern.matches(in: raw, options: [], range: full)
        if matches.isEmpty {
            return raw.isEmpty ? [] : [.text(raw)]
        }

        var segments: [ChatMessageSegment] = []
        var lastEnd = 0

        for match in matches {
            let fullRange = match.range
            if fullRange.location > lastEnd {
                let r = NSRange(location: lastEnd, length: fullRange.location - lastEnd)
                let chunk = ns.substring(with: r)
                appendText(&segments, chunk)
            }

            let tagContentRange = match.range(at: 1)
            let tagBody = ns.substring(with: tagContentRange)
            if let item = resolveItem(fromHashtagBody: tagBody) {
                segments.append(.resource(item))
            } else {
                let original = ns.substring(with: fullRange)
                appendText(&segments, original)
            }

            lastEnd = fullRange.location + fullRange.length
        }

        if lastEnd < ns.length {
            let r = NSRange(location: lastEnd, length: ns.length - lastEnd)
            appendText(&segments, ns.substring(with: r))
        }

        return mergeAdjacentText(segments)
    }

    private static func appendText(_ segments: inout [ChatMessageSegment], _ chunk: String) {
        guard !chunk.isEmpty else { return }
        segments.append(.text(chunk))
    }

    private static func mergeAdjacentText(_ segments: [ChatMessageSegment]) -> [ChatMessageSegment] {
        var out: [ChatMessageSegment] = []
        for seg in segments {
            switch (out.last, seg) {
            case (.text(let a)?, .text(let b)):
                out[out.count - 1] = .text(a + b)
            default:
                out.append(seg)
            }
        }
        return out
    }

    /// Match hashtag payload (without `#`) to a tradeable catalog item.
    static func resolveItem(fromHashtagBody body: String) -> Item? {
        let cleaned = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let key = cleaned.lowercased()
        let items = MarketCatalog.tradeableItems()

        if let hit = items.first(where: { $0.id.lowercased() == key }) {
            return hit
        }

        let keyAlnum = alphanumericKey(key)
        if let hit = items.first(where: { alphanumericKey($0.id) == keyAlnum }) {
            return hit
        }

        if let hit = items.first(where: { alphanumericKey($0.name) == keyAlnum }) {
            return hit
        }

        return nil
    }

    private static func alphanumericKey(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
