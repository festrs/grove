import SwiftUI
import SwiftData
import GroveDomain

struct PremiumSection: View {
    @Bindable var settings: UserSettings
    @State private var showingRedeemSheet = false

    var body: some View {
        Section("Plan") {
            if settings.unlimitedAssetsUnlocked {
                unlockedRow
            } else {
                freeRow
                Button {
                    showingRedeemSheet = true
                } label: {
                    Label("Redeem code", systemImage: "ticket")
                }
            }
        }
        .sheet(isPresented: $showingRedeemSheet) {
            RedeemCodeSheet()
        }
    }

    private var freeRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Free")
                    .font(.headline)
                Text("Up to \(AppConstants.freeTierMaxHoldings) assets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var unlockedRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "infinity.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.tqAccentGreen)
            VStack(alignment: .leading, spacing: 4) {
                Text("Unlimited")
                    .font(.headline)
                Text("Asset cap removed by redeem code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

