import SwiftUI
import SwiftData
import GroveDomain
import GroveServices

/// Top dividend payers ranked by trailing-12m income. Tap routes to the
/// existing `HoldingDetailView` via `PersistentIdentifier` (matches the
/// portfolio screen's navigationDestination contract).
struct TopPayersList: View {
    let payers: [IncomeAggregator.TopPayer]

    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    var body: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Top dividend payers")
                    .font(.subheadline.weight(.semibold))
                if payers.isEmpty {
                    Text("No paying holdings yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: Theme.Spacing.xs) {
                        ForEach(payers) { payer in
                            NavigationLink(value: payer.holdingID) {
                                row(for: payer)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func row(for payer: IncomeAggregator.TopPayer) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: payer.ticker)
                    .font(.subheadline.weight(.medium))
                Text(verbatim: payer.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: payer.ttm.formatted(in: displayCurrency, using: rates))
                    .font(.subheadline.weight(.semibold))
                Text(verbatim: payer.share.formattedPercent())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private extension Decimal {
    func formattedPercent() -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 1
        nf.minimumFractionDigits = 0
        let n = NSDecimalNumber(decimal: self)
        return "\(nf.string(from: n) ?? "0")%"
    }
}
