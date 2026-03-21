import SwiftUI

struct MarketHubView: View {
    let userID: String

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            LinearGradient(
                colors: [AppTheme.surface.opacity(0.12), Color.clear, AppTheme.surface.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    commandHeader
                    marketIntelRail
                    marketLaneRail
                    exchangeRail
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 10)
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
        }
    }

    private var commandHeader: some View {
        MarketRail(title: "Market Command", systemImage: "building.columns.fill", tone: .priority) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Global Exchange Hub")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Route capital across assets, resources, and contracts.")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.chipReady)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.chipReady.opacity(0.16)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.chipReady.opacity(0.45), lineWidth: 1))
                }

                HStack(spacing: 10) {
                    intelTile("MARKETS", "4", AppTheme.accent)
                    intelTile("PRIMARY", "BUILDINGS", AppTheme.chipListed)
                    intelTile("FLOW", "ACTIVE", AppTheme.chipProspecting)
                }
            }
        }
    }

    private func intelTile(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.58)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    }

    private var marketIntelRail: some View {
        MarketRail(title: "Trading Desk", systemImage: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 8) {
                intelRow("Building Market", "Acquire/sell production assets and flip strategic sites.", tint: AppTheme.chipListed)
                intelRow("Resource Market", "Exploit price inefficiencies in quality-tiered resource flow.", tint: AppTheme.chipAvailable)
                intelRow("Buy Orders", "Execute contract fulfillment for immediate cash injections.", tint: AppTheme.chipProspecting)
                intelRow("Stock Market", "Trade sector equities and rebalance your position risk.", tint: AppTheme.accent)
            }
        }
    }

    private func intelRow(_ title: String, _ detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.captionMedium())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(detail)
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.50)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    }

    private var marketLaneRail: some View {
        MarketRail(title: "Execution Lanes", systemImage: "square.grid.2x2.fill", tone: .priority) {
            VStack(spacing: 10) {
                hubCard(
                    title: "Building Market",
                    subtitle: "Buy and sell mines and rigs.",
                    systemImage: "building.2.crop.circle.fill",
                    accent: AppTheme.chipListed,
                    destination: BuildingMarketView(userID: userID)
                )

                hubCard(
                    title: "Resource Market",
                    subtitle: "Trade individual resources and materials.",
                    systemImage: "cube.box.fill",
                    accent: AppTheme.chipAvailable,
                    destination: ResourceMarketView(userID: userID)
                )
            }
        }
    }

    private var exchangeRail: some View {
        MarketRail(title: "Liquidity + Equities", systemImage: "chart.xyaxis.line") {
            VStack(spacing: 10) {
                hubCard(
                    title: "Buy Orders",
                    subtitle: "Fill large contracts for instant cash.",
                    systemImage: "doc.text.fill",
                    accent: AppTheme.chipProspecting,
                    destination: BuyOrderMarketView(userID: userID)
                )

                hubCard(
                    title: "Stock Market",
                    subtitle: "Trade sector stocks and manage positions.",
                    systemImage: "chart.pie.fill",
                    accent: AppTheme.accent,
                    destination: PortfolioView(userID: userID)
                )
            }
        }
    }

    @ViewBuilder
    private func hubCard<Destination: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        accent: Color,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.surfaceAlt.opacity(0.62))
                        .frame(width: 44, height: 44)
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
            }
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.54)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private enum MarketRailTone {
    case normal
    case priority
}

private struct MarketRail<Content: View>: View {
    let title: String
    let systemImage: String
    var tone: MarketRailTone
    private let content: Content

    init(
        title: String,
        systemImage: String,
        tone: MarketRailTone = .normal,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tone == .priority ? AppTheme.accent : AppTheme.textSecondary)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                Rectangle().fill(AppTheme.border).frame(height: 1)
            }
            content
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surface.opacity(0.82)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tone == .priority ? AppTheme.accent.opacity(0.32) : AppTheme.border.opacity(0.95), lineWidth: 1)
        )
    }
}
