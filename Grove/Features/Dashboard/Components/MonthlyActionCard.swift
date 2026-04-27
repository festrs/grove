import SwiftUI
import GroveDomain
import GroveServices

struct MonthlyActionCard: View {
    let suggestions: [RebalancingSuggestion]

    var body: some View {
        TQCard {
            HStack(spacing: 0) {
                // Green accent left border
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.tqAccentGreen)
                    .frame(width: 4)
                    .padding(.vertical, -Theme.Spacing.md)
                    .padding(.leading, -Theme.Spacing.md)
                    .padding(.trailing, Theme.Spacing.sm)

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("This month, invest in:")
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        .foregroundStyle(.primary)

                    if suggestions.isEmpty {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.tqPositive)
                            Text("Balanced portfolio!")
                                .font(.system(size: Theme.FontSize.body))
                                .foregroundStyle(Color.tqSecondaryText)
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    } else {
                        ForEach(suggestions) { suggestion in
                            suggestionRow(suggestion)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func suggestionRow(_ suggestion: RebalancingSuggestion) -> some View {
        let gap = suggestion.targetPercent - suggestion.currentPercent

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.ticker)
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))

                Text("\(gap.formattedPercent(decimals: 1)) below target")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Color.tqAccentGreen)
            }

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview("Com sugestoes") {
    MonthlyActionCard(
        suggestions: [
            RebalancingSuggestion(ticker: "BTLG11", displayName: "BTG Logistica", sharesToBuy: 5, amount: Money(amount: 500, currency: .brl), currentPercent: 8.2, targetPercent: 15, newPercent: 12),
            RebalancingSuggestion(ticker: "BCRI11", displayName: "Banestes CRI", sharesToBuy: 10, amount: Money(amount: 640, currency: .brl), currentPercent: 5.1, targetPercent: 10, newPercent: 8),
            RebalancingSuggestion(ticker: "KNRI11", displayName: "Kinea Renda", sharesToBuy: 3, amount: Money(amount: 450, currency: .brl), currentPercent: 12, targetPercent: 15, newPercent: 13.5),
        ]
    )
    .padding()
}

#Preview("Balanceado") {
    MonthlyActionCard(suggestions: [])
        .padding()
}
