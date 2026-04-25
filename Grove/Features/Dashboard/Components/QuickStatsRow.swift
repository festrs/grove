import SwiftUI

struct QuickStatsRow: View {
    let summary: PortfolioSummary
    let holdingCount: Int

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: Theme.Layout.compactCardMin), spacing: Theme.Spacing.sm)],
            spacing: Theme.Spacing.sm
        ) {
            statCard(
                label: "Patrimonio total",
                value: summary.totalValueBRL.formattedCompact(),
                prefix: "R$ "
            )

            statCard(
                label: "Renda passiva liquida",
                value: summary.monthlyIncomeNet.formattedBRL(),
                suffix: "/mes"
            )

            statCard(
                label: "Renda passiva bruta",
                value: summary.monthlyIncomeGross.formattedBRL(),
                suffix: "/mes"
            )

            statCard(
                label: "Holdings ativos",
                value: "\(summary.activeCount)",
                suffix: "/ \(holdingCount)"
            )
        }
    }

    private func statCard(
        label: String,
        value: String,
        prefix: String = "",
        suffix: String = ""
    ) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(label)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Color.tqSecondaryText)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    if !prefix.isEmpty {
                        Text(prefix)
                            .font(.system(size: Theme.FontSize.caption, weight: .medium))
                            .foregroundStyle(Color.tqSecondaryText)
                    }

                    Text(value)
                        .font(.system(size: Theme.FontSize.title3, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if !suffix.isEmpty {
                        Text(suffix)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundStyle(Color.tqSecondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    QuickStatsRow(
        summary: PortfolioSummary(
            totalValue: 245_000,
            totalValueBRL: 245_000,
            monthlyIncomeGross: 2_450,
            monthlyIncomeNet: 2_100,
            allocationByClass: [],
            studyCount: 1,
            activeCount: 12,
            quarantineCount: 2,
            sellingCount: 1
        ),
        holdingCount: 15
    )
    .padding()
}
