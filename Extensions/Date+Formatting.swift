//
//  Date+Formatting.swift
//  Boardroom Tycoon
//
//  Extensions for Date formatting. Add shared date formatters and helpers here.
//

import Foundation

extension Date {
    /// Time only (locale-aware), e.g. `3:45 PM` or `15:45` — for chat bubbles.
    func formattedChatTimeOnly() -> String {
        Self.chatTimeOnlyFormatter.string(from: self)
    }

    private static let chatTimeOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}
