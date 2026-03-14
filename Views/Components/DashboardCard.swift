//
//  DashboardCard.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct DashboardCard<Destination: View>: View {
    let title: String
    let systemImage: String
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination.navigationTitle(title)) {
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackground)

                VStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ZStack {
            AppTheme.background.ignoresSafeArea()
        }
        .overlay {
            DashboardCard(
                title: "Operations",
                systemImage: "gearshape",
                destination: Text("Destination")
            )
            .padding()
        }
    }
}
