import SwiftUI
import GroveDomain
import GroveServices
import GroveRepositories

struct SummaryCardsRow: View {
    let summary: PortfolioSummary
    let projection: IncomeProjection?
    let portfolioCount: Int
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
            spacing: 12
        ) {
            summaryCard(
                label: "Assets",
                value: summary.totalValue.amount.formattedCompact(),
                prefix: "\(summary.totalValue.currency.symbol) "
            )
            summaryCard(
                label: "Gross Income",
                value: summary.monthlyIncomeGross.formatted(in: displayCurrency, using: rates),
                hint: "/mes"
            )
            summaryCard(
                label: "Net Income",
                value: summary.monthlyIncomeNet.formatted(in: displayCurrency, using: rates),
                hint: "After taxes",
                accent: true
            )
            if let years = projection?.estimatedYearsToGoal {
                let formatted = String(format: "%.1f", NSDecimalNumber(decimal: years).doubleValue)
                summaryCard(
                    label: "FI in",
                    value: "\(formatted) years",
                    hint: "At current pace"
                )
            }
            if portfolioCount > 0 {
                summaryCard(
                    label: "Portfolios",
                    value: "\(portfolioCount)",
                    hint: portfolioCount == 1
                        ? String(localized: "1 portfolio")
                        : String(localized: "\(portfolioCount) portfolios")
                )
            }
        }
    }

    private func summaryCard(
        label: String,
        value: String,
        prefix: String = "",
        hint: String = "",
        accent: Bool = false
    ) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    if !prefix.isEmpty {
                        Text(prefix)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(value)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(accent ? Color.tqAccentGreen : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                if !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
