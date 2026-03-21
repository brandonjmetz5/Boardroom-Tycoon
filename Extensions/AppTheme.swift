//
//  AppTheme.swift
//  Boardroom Tycoon
//
//  Executive / tycoon design system: deep navy, gold accent, clear hierarchy.
//

import SwiftUI

enum AppTheme {
    // MARK: - Backgrounds

    /// Main app background (neutral charcoal).
    static let background = Color(red: 0.16, green: 0.16, blue: 0.20)

    /// Card and elevated surface.
    static let surface = Color(red: 0.16, green: 0.16, blue: 0.20)

    /// Slightly lighter surface (pills, secondary cards).
    static let surfaceAlt = Color(red: 0.22, green: 0.22, blue: 0.28)

    /// Tab bar / bottom bar background.
    static let tabBarBackground = Color(red: 0.06, green: 0.06, blue: 0.08)

    /// Subtle border.
    static let border = Color.white.opacity(0.20)

    /// Backward compatibility.
    static let cardBackground = surface
    static let cardBackgroundAlt = surfaceAlt
    static let cardBorder = border

    // MARK: - Text

    static let textPrimary = Color(red: 0.98, green: 0.98, blue: 1.0)
    static let textSecondary = Color.white.opacity(0.72)
    static let textTertiary = Color.white.opacity(0.52)
    static let textMuted = Color.white.opacity(0.44)
    static let textError = Color(red: 0.95, green: 0.40, blue: 0.40)

    // MARK: - Accent (gold / executive)

    // Executive red tuned for dark backgrounds.
    static let accent = Color(red: 0.92, green: 0.30, blue: 0.30)
    static let accentDim = Color(red: 0.92, green: 0.30, blue: 0.30).opacity(0.72)

    // MARK: - Status chips

    static let chipListed = Color(red: 0.50, green: 0.42, blue: 0.85)
    static let chipReady = Color(red: 0.28, green: 0.65, blue: 0.48)
    static let chipProducing = Color(red: 0.82, green: 0.58, blue: 0.24)
    static let chipIdle = Color(red: 0.40, green: 0.44, blue: 0.52)
    static let chipAvailable = Color(red: 0.38, green: 0.52, blue: 0.82)
    static let chipProspecting = Color(red: 0.32, green: 0.55, blue: 0.82)
    static let chipPositive = Color(red: 0.28, green: 0.65, blue: 0.48)
    static let chipNegative = Color(red: 0.92, green: 0.35, blue: 0.35)

    // MARK: - Layout

    static let cardCornerRadius: CGFloat = 20
    static let pillCornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let horizontalPadding: CGFloat = 20

    // MARK: - Typography (semantic)

    static func titleLarge() -> Font { .system(size: 28, weight: .bold, design: .rounded) }
    static func titleMedium() -> Font { .system(size: 22, weight: .semibold, design: .rounded) }
    static func titleSmall() -> Font { .system(size: 18, weight: .semibold) }
    static func body() -> Font { .system(size: 15, weight: .regular) }
    static func bodyMedium() -> Font { .system(size: 15, weight: .medium) }
    static func caption() -> Font { .system(size: 13, weight: .regular) }
    static func captionMedium() -> Font { .system(size: 12, weight: .medium) }
    static func monoNumber() -> Font { .system(size: 17, weight: .semibold, design: .monospaced) }
}

// MARK: - View helpers

extension View {
    func appCard(cornerRadius: CGFloat = AppTheme.cardCornerRadius) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }

    func appPill() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: AppTheme.pillCornerRadius, style: .continuous)
                    .fill(AppTheme.surfaceAlt)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.pillCornerRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }

    /// Legacy alias so existing themedCard/themedPill still work.
    func themedCard(cornerRadius: CGFloat = AppTheme.cardCornerRadius) -> some View {
        appCard(cornerRadius: cornerRadius)
    }

    func themedPill() -> some View {
        appPill()
    }
}
