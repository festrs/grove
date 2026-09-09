import SwiftUI
import GroveDomain
import GroveServices

struct RebalancingResultRow: View {
    let suggestion: RebalancingSuggestion
    @Binding var shares: Int
    let amount: Money

    private var isEdited: Bool { shares != suggestion.sharesToBuy }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.displayTicker)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(suggestion.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(amount.formatted())
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 4) {
                    TextField("", value: $shares, format: .number)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                        .frame(width: 44)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Stepper(value: $shares, in: 0...9999) {}
                        .labelsHidden()
                }
                Text("shares")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !isEdited {
                    HStack(spacing: 4) {
                        Text(suggestion.currentPercent.formattedPercent())
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(suggestion.newPercent.formattedPercent())
                            .foregroundStyle(Color.tqAccentGreen)
                    }
                    .font(.caption2)
                }
            }
        }
    }
}

#Preview {
    let suggestion = RebalancingSuggestion(
        ticker: "ITUB3.SA",
        displayName: "Itau Unibanco",
        sharesToBuy: 10,
        amount: Money(amount: 320, currency: .brl),
        currentPercent: 18,
        targetPercent: 25,
        newPercent: 22
    )
    RebalancingResultRow(
        suggestion: suggestion,
        shares: .constant(10),
        amount: Money(amount: 320, currency: .brl)
    )
    .padding()
}
