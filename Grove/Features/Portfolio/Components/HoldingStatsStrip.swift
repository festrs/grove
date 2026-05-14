import SwiftUI
import GroveDomain

/// Horizontal scrolling stat cards strip — Apple Stocks style.
/// Combines portfolio stats and fundamentals into a single scrollable row.
struct HoldingStatsStrip: View {
    let holding: Holding
    let fundamentals: FundamentalsDTO?
    let isFundamentalsLoading: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                portfolioCard
                incomeCard
                if holding.assetClass.hasFundamentals {
                    fundamentalsCards
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.horizontal, -Theme.Spacing.md)
    }

    // MARK: - Portfolio Card

    private var portfolioCard: some View {
        let gl = holding.gainLossPercent
        return groupCard(rows: [
            ("Total Value", holding.currentValueMoney.formatted(), .standard),
            ("Average Price", holding.averagePriceMoney.formatted(), .standard),
            ("Gain/Loss", "\(gl >= 0 ? "+" : "")\(gl.formattedPercent())", .color(holding.gainLossColor)),
        ])
    }

    @ViewBuilder
    private var incomeCard: some View {
        if holding.assetClass.hasDividends {
            groupCard(rows: [
                ("Estimated DY", holding.dividendYield.formattedPercent(), .standard),
                ("Gross Income", holding.estimatedMonthlyIncomeMoney().formatted(), .standard),
                ("Net Income", holding.estimatedMonthlyIncomeNetMoney().formatted(), .accent),
            ])
        }
    }

    // MARK: - Fundamentals Cards

    @ViewBuilder
    private var fundamentalsCards: some View {
        if isFundamentalsLoading {
            groupCard(rows: [("Fundamentals", "...", .standard)])
        } else if let data = fundamentals {
            qualityCard(data)
            financialCard(data)
        }
    }

    @ViewBuilder
    private func qualityCard(_ data: FundamentalsDTO) -> some View {
        let rows = buildQualityRows(data)
        if !rows.isEmpty {
            groupCard(rows: rows)
        }
    }

    @ViewBuilder
    private func financialCard(_ data: FundamentalsDTO) -> some View {
        let rows = buildFinancialRows(data)
        if !rows.isEmpty {
            groupCard(rows: rows)
        }
    }

    private func buildQualityRows(_ data: FundamentalsDTO) -> [(String, String, CardStyle)] {
        var rows: [(String, String, CardStyle)] = []
        if let score = data.compositeScore {
            rows.append(("Score", String(format: "%.0f", score), .color(data.scoreColor)))
        }
        if let profitable = data.profitableYearsPct {
            rows.append(("Consistent Profits", String(format: "%.0f%%", profitable), .color(data.profitColor)))
        }
        if let eps = data.epsGrowthPct {
            rows.append(("EPS Growth", String(format: "%+.1f%%", eps), .color(data.epsColor)))
        }
        return rows
    }

    private func buildFinancialRows(_ data: FundamentalsDTO) -> [(String, String, CardStyle)] {
        var rows: [(String, String, CardStyle)] = []
        if let debt = data.currentNetDebtEbitda {
            rows.append(("Debt/EBITDA", String(format: "%.1fx", debt), .color(data.debtColor)))
        }
        if let highDebt = data.highDebtYearsPct {
            rows.append(("High Debt Yrs", String(format: "%.0f%%", highDebt), .color(data.debtColor)))
        }
        if let years = data.ipoYears {
            rows.append(("Years Listed", "\(years) yrs", .color(data.ipoColor)))
        }
        return rows
    }

    // MARK: - Group Card (up to 4 rows)

    private enum CardStyle {
        case standard, positive, negative, warning, accent
        case color(Color)
    }

    private func groupCard(rows: [(label: String, value: String, style: CardStyle)]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(Array(rows.prefix(3).enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(row.value)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(colorFor(row.style))
                }
            }
        }
        .frame(width: 180)
        .padding(Theme.Spacing.sm)
        .background(Color.tqCardBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    // MARK: - Colors

    private func colorFor(_ style: CardStyle) -> Color {
        switch style {
        case .standard: .primary
        case .positive: .tqPositive
        case .negative: .tqNegative
        case .warning: .tqWarning
        case .accent: .tqAccentGreen
        case .color(let c): c
        }
    }
}
