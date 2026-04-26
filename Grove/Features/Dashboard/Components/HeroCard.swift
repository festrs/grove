import SwiftUI

struct HeroCard: View {
    let projection: IncomeProjection
    let suggestions: [RebalancingSuggestion]
    @Environment(\.displayCurrency) private var displayCurrency

    var body: some View {
        TQCard {
            VStack(spacing: 0) {
                // Top: Meter + Action text
                HStack(alignment: .center, spacing: Theme.Spacing.xl) {
                    TQProgressRing(
                        progress: NSDecimalNumber(decimal: projection.progressPercent).doubleValue / 100.0,
                        lineWidth: 14,
                        size: 200,
                        accentColor: projection.progressPercent >= 100 ? Color.tqPositive : Color.tqAccentGreen
                    )
                    .overlay {
                        VStack(spacing: Theme.Spacing.xs) {
                            Text("PASSIVE INCOME · MONTH")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .tracking(0.6)
                            Text(projection.currentMonthlyNet.formatted(as: displayCurrency))
                                .font(.system(size: 32, weight: .bold))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text("of \(projection.goalMonthly.formatted(as: displayCurrency))")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("For this month")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)
                            .textCase(.uppercase)

                        if !suggestions.isEmpty {
                            Text("Invest in \(suggestions.count) assets below target")
                                .font(.system(size: 22, weight: .bold))
                                .lineLimit(2)
                        }

                        if let years = projection.estimatedYearsToGoal {
                            let pctLeft = 100 - NSDecimalNumber(decimal: projection.progressPercent).doubleValue
                            let formatted = String(format: "%.1f", NSDecimalNumber(decimal: years).doubleValue)
                            Text("~\(formatted) years left · \(String(format: "%.0f", pctLeft))% remaining")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Theme.Spacing.lg)

                // Bottom: Suggested tickers
                if !suggestions.isEmpty {
                    Divider()
                    HStack(spacing: 0) {
                        ForEach(Array(suggestions.prefix(3).enumerated()), id: \.element.id) { index, suggestion in
                            if index > 0 {
                                Divider()
                            }
                            suggestionTile(suggestion)
                        }
                    }
                }
            }
        }
    }

    private func suggestionTile(_ suggestion: RebalancingSuggestion) -> some View {
        HStack(spacing: 12) {
            tickerSwatch(suggestion.displayTicker)

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.displayTicker)
                    .font(.system(size: 15, weight: .semibold))
                let gap = NSDecimalNumber(decimal: suggestion.targetPercent - suggestion.currentPercent).doubleValue
                Text("-\(String(format: "%.0f", abs(gap)))% of target")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(suggestion.amount.formatted(as: displayCurrency))
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }

    private func tickerSwatch(_ ticker: String) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.tqAccentGreen.opacity(0.15))
            .frame(width: 38, height: 38)
            .overlay {
                Text(String(ticker.prefix(4)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.tqAccentGreen)
            }
    }
}
