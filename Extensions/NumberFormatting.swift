//
//  NumberFormatting.swift
//  Boardroom Tycoon
//
//  Standard display formatting for currency and quantities: thousands separators (en_US).
//

import Foundation

/// App-wide number formatting for UI strings. Uses a fixed US locale so grouping is consistent in-game.
enum NumberFormatting {
    static let displayLocale = Locale(identifier: "en_US")

    /// USD with a fixed fraction length (0 = whole dollars, 2 = cents).
    static func currency(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(
            .currency(code: "USD")
                .locale(displayLocale)
                .precision(.fractionLength(fractionDigits))
        )
    }

    /// Non-currency decimal with grouping (quantities, shares, rates).
    static func decimal(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(
            .number
                .locale(displayLocale)
                .precision(.fractionLength(fractionDigits))
                .grouping(.automatic)
        )
    }

    /// Whole numbers with grouping.
    static func integer(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic).locale(displayLocale))
    }

    /// Signed currency, e.g. `+$1,234.56` or `-$10.00`.
    static func signedCurrency(_ value: Double, fractionDigits: Int) -> String {
        let sign = value >= 0 ? "+" : "-"
        return sign + currency(abs(value), fractionDigits: fractionDigits)
    }

    /// Whole-number delta with sign and `%`, e.g. `+12%` or `-3%`.
    static func signedPercentWhole(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        let n = Int(abs(value).rounded())
        return "\(sign)\(integer(n))%"
    }

    /// Parses user-entered decimals (e.g. TextField) with optional thousands separators.
    static func parseDecimalInput(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let f = NumberFormatter()
        f.locale = displayLocale
        f.numberStyle = .decimal
        f.isLenient = true
        if let n = f.number(from: trimmed) { return n.doubleValue }
        // Fallback: lone comma as decimal (e.g. `1,5`)
        if !trimmed.contains("."), trimmed.filter({ $0 == "," }).count == 1 {
            return Double(trimmed.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }
}
