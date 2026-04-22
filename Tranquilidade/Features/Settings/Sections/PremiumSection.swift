import SwiftUI

struct PremiumSection: View {
    var body: some View {
        Section("Plano") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gratuito")
                        .font(.headline)
                    Text("Ate 10 ativos, 1 portfolio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Upgrade") {
                    // RevenueCat paywall - Phase 8
                }
                .buttonStyle(.borderedProminent)
                .tint(.tqAccentGreen)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Premium - R$ 9,90/mes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Ativos ilimitados, multiplos portfolios, widgets, notificacoes, exportacao")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
