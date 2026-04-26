import SwiftUI

struct RebalancingResultRow: View {
    let suggestion: RebalancingSuggestion

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.ticker)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(suggestion.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(suggestion.amount.formatted())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(suggestion.sharesToBuy) shares")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
