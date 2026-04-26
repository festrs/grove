import SwiftUI
import SwiftData

struct HoldingsTableView: View {
    let holdings: [Holding]
    let totalValue: Money
    var onSelect: (PersistentIdentifier) -> Void = { _ in }
    var onChangeStatus: (Holding, HoldingStatus) -> Void = { _, _ in }
    var onBuy: (Holding) -> Void = { _ in }
    var onSell: (Holding) -> Void = { _ in }
    var onRemove: (Holding) -> Void = { _ in }

    @Environment(\.rates) private var rates
    @State private var sortOrder = [KeyPathComparator(\HoldingTableRow.ticker)]

    private var rows: [HoldingTableRow] {
        holdings.map { HoldingTableRow(holding: $0, totalValue: totalValue, rates: rates) }
    }

    private var sortedRows: [HoldingTableRow] {
        rows.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedRows, sortOrder: $sortOrder) {
            TableColumn("Ticker", value: \.ticker) { row in
                HStack(spacing: 8) {
                    Circle()
                        .fill(row.holding.assetClass.color.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: row.holding.assetClass.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(row.holding.assetClass.color)
                        }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.holding.displayTicker)
                            .font(.system(.body, weight: .semibold))
                        Text(row.holding.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .width(min: 120, ideal: 160)

            TableColumn("Qty", value: \.quantityValue) { row in
                Text("\(row.holding.quantity)")
                    .monospacedDigit()
            }
            .width(min: 50, ideal: 70)

            TableColumn("Price", value: \.priceValue) { row in
                Text(row.holding.priceMoney.formatted())
                    .monospacedDigit()
            }
            .width(min: 80, ideal: 100)

            TableColumn("Gain", value: \.gainValue) { row in
                let gain = row.holding.gainLossPercent
                HStack(spacing: 2) {
                    Image(systemName: gain >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(gain.formattedPercent())
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    gain >= 0 ? Color.tqPositive : Color.tqNegative,
                    in: RoundedRectangle(cornerRadius: 4)
                )
            }
            .width(min: 80, ideal: 90)

            TableColumn("Allocation", value: \.allocationValue) { row in
                Text(row.allocation.formattedPercent())
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 70, ideal: 80)

            TableColumn("Income/Mo", value: \.incomeValue) { row in
                Text(row.holding.estimatedMonthlyIncomeNetMoney.formatted())
                    .monospacedDigit()
                    .foregroundStyle(Color.tqAccentGreen)
            }
            .width(min: 90, ideal: 110)

            TableColumn("Status") { row in
                TQStatusBadge(status: row.holding.status)
            }
            .width(min: 80, ideal: 90)
        }
        .contextMenu(forSelectionType: HoldingTableRow.ID.self) { ids in
            if let id = ids.first, let row = sortedRows.first(where: { $0.id == id }) {
                holdingContextMenu(row.holding)
            }
        } primaryAction: { ids in
            if let id = ids.first, let row = sortedRows.first(where: { $0.id == id }) {
                onSelect(row.holding.persistentModelID)
            }
        }
    }

    @ViewBuilder
    private func holdingContextMenu(_ holding: Holding) -> some View {
        Button {
            onBuy(holding)
        } label: {
            Label("Buy", systemImage: "plus.circle.fill")
        }

        Button {
            onSell(holding)
        } label: {
            Label("Sell", systemImage: "minus.circle.fill")
        }

        Divider()

        Menu("Status") {
            ForEach(HoldingStatus.allCases) { status in
                Button {
                    onChangeStatus(holding, status)
                } label: {
                    Label(status.displayName, systemImage: status.icon)
                }
                .disabled(holding.status == status)
            }
        }

        Divider()

        Button(role: .destructive) {
            onRemove(holding)
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }
}

// MARK: - Table Row Model

struct HoldingTableRow: Identifiable, Comparable {
    let holding: Holding
    let totalValue: Money
    let rates: any ExchangeRates

    var id: PersistentIdentifier { holding.persistentModelID }
    var ticker: String { holding.ticker }
    var quantityValue: Double { NSDecimalNumber(decimal: holding.quantity).doubleValue }
    var priceValue: Double { NSDecimalNumber(decimal: holding.currentPrice).doubleValue }
    var gainValue: Double { NSDecimalNumber(decimal: holding.gainLossPercent).doubleValue }
    var incomeValue: Double { NSDecimalNumber(decimal: holding.estimatedMonthlyIncomeNet).doubleValue }
    var allocationValue: Double { NSDecimalNumber(decimal: allocation).doubleValue }

    var allocation: Decimal {
        guard totalValue.amount > 0 else { return 0 }
        let displayValue = holding.currentValueMoney.converted(to: totalValue.currency, using: rates).amount
        return (displayValue / totalValue.amount) * 100
    }

    static func == (lhs: HoldingTableRow, rhs: HoldingTableRow) -> Bool {
        lhs.id == rhs.id
    }

    static func < (lhs: HoldingTableRow, rhs: HoldingTableRow) -> Bool {
        lhs.ticker < rhs.ticker
    }
}
