import SwiftUI

struct SummaryCardsRow: View {
    let summary: PortfolioSummary
    let projection: IncomeProjection?
    @Environment(\.displayCurrency) private var displayCurrency

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
            spacing: 12
        ) {
            summaryCard(
                label: "Assets",
                value: summary.totalValue.formattedCompact(),
                prefix: "\(displayCurrency.symbol) "
            )
            summaryCard(
                label: "Gross Income",
                value: summary.monthlyIncomeGross.formatted(as: displayCurrency),
                hint: "/mes"
            )
            summaryCard(
                label: "Net Income",
                value: summary.monthlyIncomeNet.formatted(as: displayCurrency),
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
