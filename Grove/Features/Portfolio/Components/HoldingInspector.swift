import SwiftUI
import SwiftData
import GroveDomain

/// Right-rail inspector shown at regular width when a holding is selected
/// in `HoldingsListView`. Surfaces the most-used facts (value, gain/loss,
/// estimated income, next/last dividend) without leaving the portfolio
/// canvas. The "Open detail" button pushes `HoldingDetailView` for the
/// full chart + fundamentals + history.
struct HoldingInspector: View {
    let holdingID: PersistentIdentifier
    let onOpenDetail: () -> Void
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    @State private var holding: Holding?

    var body: some View {
        Group {
            if let holding {
                content(holding)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: holdingID) {
            holding = modelContext.model(for: holdingID) as? Holding
        }
    }

    @ViewBuilder
    private func content(_ holding: Holding) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header(holding)
                valueStrip(holding)
                if holding.assetClass.hasDividends {
                    incomeStrip(holding)
                    dividendsPreview(holding)
                }
                Button(action: onOpenDetail) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open detail")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.tqAccentGreen)
            }
            .padding(Theme.Spacing.md)
        }
    }

    private func header(_ holding: Holding) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.displayTicker).font(.title2).fontWeight(.bold)
                Text(holding.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
    }

    private func valueStrip(_ holding: Holding) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                statRow("Total Value", holding.currentValueMoney.formatted())
                statRow("Avg Price", holding.averagePriceMoney.formatted())
                let gl = holding.gainLossPercent
                statRow(
                    "Gain / Loss",
                    "\(gl >= 0 ? "+" : "")\(gl.formattedPercent())",
                    color: holding.gainLossColor
                )
                statRow("Quantity", "\(holding.quantity)")
            }
        }
    }

    private func incomeStrip(_ holding: Holding) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                statRow("Estimated DY", holding.dividendYield.formattedPercent())
                statRow("Gross / mo", holding.estimatedMonthlyIncomeMoney().formatted())
                statRow(
                    "Net / mo",
                    holding.estimatedMonthlyIncomeNetMoney().formatted(),
                    color: Color.tqAccentGreen
                )
            }
        }
    }

    private func dividendsPreview(_ holding: Holding) -> some View {
        let paid = Array(holding.paidDividends.prefix(3))
        let projected = Array(holding.projectedDividends.prefix(3))
        return TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Dividends").font(.headline)
                if paid.isEmpty && projected.isEmpty {
                    Text("No dividend records yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !projected.isEmpty {
                    Text("Upcoming")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(projected, id: \.persistentModelID) { d in
                        dividendRow(d, isProjected: true)
                    }
                }
                if !paid.isEmpty {
                    Text("Recent")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, projected.isEmpty ? 0 : Theme.Spacing.xs)
                    ForEach(paid, id: \.persistentModelID) { d in
                        dividendRow(d, isProjected: false)
                    }
                }
            }
        }
    }

    private func dividendRow(_ d: DividendPayment, isProjected: Bool) -> some View {
        HStack {
            Text(d.paymentDate.formatted(.dateTime.day().month().year()))
                .font(.caption)
            Spacer()
            Text(d.totalAmountMoney.formatted())
                .font(.caption)
                .foregroundStyle(isProjected ? Color.secondary : Color.tqAccentGreen)
        }
    }

    private func statRow(_ label: String, _ value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}
