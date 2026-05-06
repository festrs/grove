import SwiftUI

struct PremiumSection: View {
    var body: some View {
        Section("Plan") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Free")
                        .font(.headline)
                    Text("Up to 10 assets")
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
                Text("Premium - R$ 9.90/month")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Unlimited assets, widgets, notifications, export")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
