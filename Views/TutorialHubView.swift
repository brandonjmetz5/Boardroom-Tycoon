import SwiftUI

struct TutorialHubView: View {
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            LinearGradient(
                colors: [AppTheme.surface.opacity(0.12), Color.clear, AppTheme.surface.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                rail(title: "Tutorial Hub", systemImage: "graduationcap.fill", tone: .priority) {
                    Text("This will become the tutorial / how-to hub. For now it’s a placeholder destination from the dashboard menu.")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                }

                rail(title: "Planned Guides", systemImage: "checklist") {
                    VStack(alignment: .leading, spacing: 8) {
                        bullet("Prospect a mine and keep it")
                        bullet("Start production and collect output")
                        bullet("List inventory on the market")
                        bullet("Place a buy order and fulfill one")
                    }
                }

                Spacer()
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 12)
        }
        .navigationTitle("Tutorial")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.surface, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textTertiary)
            Text(text)
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func rail<Content: View>(
        title: String,
        systemImage: String,
        tone: RailTone = .normal,
        @ViewBuilder content: () -> Content
    ) -> some View {
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
            content()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surface.opacity(0.82)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tone == .priority ? AppTheme.accent.opacity(0.32) : AppTheme.border.opacity(0.95), lineWidth: 1)
        )
    }
}

private enum RailTone {
    case normal
    case priority
}

