//
//  AppTheme.swift
//  Boardroom Tycoon
//
//  Shared colors and styles matching the Operations screen. Use for a consistent dark, finished look.
//

import SwiftUI

enum AppTheme {
    // MARK: - Backgrounds

    /// Main screen background (dark blue‑gray).
    static let background = Color(red: 0.03, green: 0.05, blue: 0.07)

    /// Card and pill background.
    static let cardBackground = Color(red: 0.07, green: 0.10, blue: 0.13)

    /// Slightly lighter card (e.g. prospecting, alternate sections).
    static let cardBackgroundAlt = Color(red: 0.08, green: 0.11, blue: 0.15)

    /// Subtle border on cards.
    static let cardBorder = Color.white.opacity(0.04)

    // MARK: - Text

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.68)
    static let textTertiary = Color.white.opacity(0.56)
    static let textMuted = Color.white.opacity(0.58)
    static let textError = Color.red

    // MARK: - Accents (status / chips)

    static let chipListed = Color(red: 0.42, green: 0.37, blue: 0.78)
    static let chipReady = Color(red: 0.24, green: 0.62, blue: 0.44)
    static let chipProducing = Color(red: 0.76, green: 0.55, blue: 0.22)
    static let chipIdle = Color(red: 0.34, green: 0.39, blue: 0.47)
    static let chipAvailable = Color(red: 0.37, green: 0.49, blue: 0.78)
    static let chipProspecting = Color(red: 0.30, green: 0.53, blue: 0.78)
    static let chipPositive = Color(red: 0.24, green: 0.62, blue: 0.44)
    static let chipNegative = Color(red: 0.85, green: 0.35, blue: 0.35)

    // MARK: - Layout

    static let cardCornerRadius: CGFloat = 30
    static let pillCornerRadius: CGFloat = 22
    static let cardPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 20
    static let horizontalPadding: CGFloat = 16
}

// MARK: - View helpers

extension View {
    /// Card container: dark fill, rounded, thin border.
    func themedCard(cornerRadius: CGFloat = AppTheme.cardCornerRadius) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
    }

    /// Pill-style container for small stats or labels.
    func themedPill() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: AppTheme.pillCornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackgroundAlt)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.pillCornerRadius, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
    }
}
