import SwiftUI

struct MarketHubView: View {
    let userID: String

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Market")
                        .font(AppTheme.titleMedium())
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.top, 8)

                    Text("Choose which part of the market you want to explore. Flip buildings, trade resources, or fulfill big buy orders.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    hubCard(
                        title: "Building Market",
                        subtitle: "Buy and sell mines and rigs.",
                        systemImage: "building.2.crop.circle",
                        destination: BuildingMarketView(userID: userID)
                    )

                    hubCard(
                        title: "Resource Market",
                        subtitle: "Trade individual resources and materials.",
                        systemImage: "cube.box.fill",
                        destination: ResourceMarketView(userID: userID)
                    )

                    hubCard(
                        title: "Buy Orders",
                        subtitle: "Fill large contracts for instant cash.",
                        systemImage: "doc.text.fill",
                        destination: BuyOrderMarketView(userID: userID)
                    )
                }
                .padding(AppTheme.horizontalPadding)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Market")
                    .font(AppTheme.titleMedium())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: InventoryView(userID: userID)) {
                    Image(systemName: "building.2")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private func hubCard<Destination: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.cardBackgroundAlt.opacity(0.95))
                        .frame(width: 48, height: 48)
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
        }
        .buttonStyle(.plain)
    }
}

