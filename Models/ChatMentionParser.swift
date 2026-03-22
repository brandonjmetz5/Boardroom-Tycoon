//
//  ChatMentionParser.swift
//  Boardroom Tycoon
//
//  Extracts @userId tokens from chat text (Firebase Auth UIDs are long alphanumeric strings).
//

import Foundation

enum ChatMentionParser {
    /// Typical Firebase UID length is 28; use a floor to avoid matching @team or @all.
    private static let minUidLength = 20
    private static let maxTokenLength = 128

    private static let pattern = try! NSRegularExpression(
        pattern: #"@([A-Za-z0-9]+)"#,
        options: []
    )

    /// Unique mentioned user ids found in `text` (does not validate UIDs exist).
    static func mentionedUserIds(in text: String, excluding senderId: String) -> [String] {
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = pattern.matches(in: text, options: [], range: range)
        var seen = Set<String>()
        var out: [String] = []
        for m in matches {
            guard m.numberOfRanges >= 2 else { continue }
            let r = m.range(at: 1)
            let token = ns.substring(with: r)
            guard token.count >= minUidLength, token.count <= maxTokenLength else { continue }
            guard token != senderId else { continue }
            if seen.insert(token).inserted {
                out.append(token)
            }
        }
        return out
    }
}
