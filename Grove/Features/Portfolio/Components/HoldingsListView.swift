import SwiftUI
import SwiftData
import GroveDomain

/// Wide-layout (iPad + macOS) replacement for the previous `Table`-backed
/// holdings view. Rendered as a `LazyVStack` of custom rows so the parent
/// `ScrollView` can scroll the portfolio hero off-screen while the column
/// header (and filter tabs) stay pinned.
struct HoldingsListView: View {
    let holdings: [Holding]
    let totalValue: Money
    var onSelect: (PersistentIdentifier) -> Void = { _ in }
    var onChangeStatus: (Holding, HoldingStatus) -> Void = { _, _ in }
    var onBuy: (Holding) -> Void = { _ in }
    var onSell: (Holding) -> Void = { _ in }
    var onRemove: (Holding) -> Void = { _ in }

    @Environment(\.rates) private var rates
    @Binding var sortOrder: [KeyPathComparator<HoldingTableRow>]

    private var rows: [HoldingTableRow] {
        holdings.map { HoldingTableRow(holding: $0, totalValue: totalValue, rates: rates) }
    }

    private var sortedRows: [HoldingTableRow] {
        rows.sorted(using: sortOrder)
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(sortedRows) { row in
                HoldingRowView(
                    row: row,
                    onChangeStatus: onChangeStatus
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(row.holding.persistentModelID)
                }
                .contextMenu {
                    holdingContextMenu(row.holding)
                }
                Divider().opacity(0.4)
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

// MARK: - Column layout

enum HoldingsColumn: String, CaseIterable {
    case ticker, qty, price, gain, allocation, income, status

    var title: String {
        switch self {
        case .ticker: "Ticker"
        case .qty: "Qty"
        case .price: "Price"
        case .gain: "Gain"
        case .allocation: "Allocation"
        case .income: "Income/Mo"
        case .status: "Status"
        }
    }

    var width: CGFloat? {
        switch self {
        case .ticker: nil      // flexible — shrinks via lineLimit(1) on contents
        case .qty: 52
        case .price: 78
        case .gain: 60
        case .allocation: 64
        case .income: 84
        case .status: 88
        }
    }

    var alignment: Alignment {
        switch self {
        case .ticker: .leading
        case .status: .trailing
        default: .trailing
        }
    }

    var comparator: KeyPathComparator<HoldingTableRow>? {
        switch self {
        case .ticker: KeyPathComparator(\.ticker)
        case .qty: KeyPathComparator(\.quantityValue)
        case .price: KeyPathComparator(\.priceValue)
        case .gain: KeyPathComparator(\.gainValue)
        case .allocation: KeyPathComparator(\.allocationValue)
        case .income: KeyPathComparator(\.incomeValue)
        case .status: nil
        }
    }
}

/// Sticky column header bar — clickable titles that drive a
/// `KeyPathComparator` sort the same way SwiftUI `Table` does.
struct HoldingsColumnHeader: View {
    @Binding var sortOrder: [KeyPathComparator<HoldingTableRow>]

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(HoldingsColumn.allCases, id: \.rawValue) { column in
                headerCell(column)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(Color.tqBackground)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private func headerCell(_ column: HoldingsColumn) -> some View {
        HStack(spacing: 4) {
            if column.alignment == .trailing {
                Spacer(minLength: 0)
            }
            Text(column.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let indicator = sortIndicator(for: column) {
                Image(systemName: indicator)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            if column.alignment == .leading {
                Spacer(minLength: 0)
            }
        }
        .frame(width: column.width, alignment: column.alignment)
        .frame(maxWidth: column.width == nil ? .infinity : nil, alignment: column.alignment)
        .contentShape(Rectangle())
        .onTapGesture {
            if column.comparator != nil {
                toggleSort(column)
            }
        }
    }

    private func sortIndicator(for column: HoldingsColumn) -> String? {
        guard let comparator = column.comparator,
              let active = sortOrder.first,
              active.keyPath == comparator.keyPath else {
            return nil
        }
        return active.order == .forward ? "chevron.up" : "chevron.down"
    }

    private func toggleSort(_ column: HoldingsColumn) {
        guard var comparator = column.comparator else { return }
        if let active = sortOrder.first, active.keyPath == comparator.keyPath {
            comparator.order = active.order == .forward ? .reverse : .forward
        }
        sortOrder = [comparator]
    }
}

// MARK: - Row

struct HoldingRowView: View {
    let row: HoldingTableRow
    var onChangeStatus: (Holding, HoldingStatus) -> Void = { _, _ in }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            tickerCell
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(row.holding.quantity)")
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: HoldingsColumn.qty.width, alignment: .trailing)

            Text(row.holding.priceMoney.formatted())
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: HoldingsColumn.price.width, alignment: .trailing)

            gainCell
                .frame(width: HoldingsColumn.gain.width, alignment: .trailing)

            Text(row.allocation.formattedPercent())
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: HoldingsColumn.allocation.width, alignment: .trailing)

            Text(row.holding.estimatedMonthlyIncomeNetMoney().formatted())
                .monospacedDigit()
                .foregroundStyle(Color.tqAccentGreen)
                .lineLimit(1)
                .frame(width: HoldingsColumn.income.width, alignment: .trailing)

            statusMenu
                .frame(width: HoldingsColumn.status.width, alignment: .trailing)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(maxWidth: .infinity)
    }

    private var statusMenu: some View {
        Menu {
            ForEach(HoldingStatus.allCases) { status in
                Button {
                    onChangeStatus(row.holding, status)
                } label: {
                    Label(status.displayName, systemImage: status.icon)
                }
                .disabled(row.holding.status == status)
            }
        } label: {
            TQStatusBadge(status: row.holding.status)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var tickerCell: some View {
        HStack(spacing: Theme.Spacing.sm) {
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
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.holding.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(0)  // numeric columns win when space is tight
        }
    }

    private var gainCell: some View {
        let gain = row.holding.gainLossPercent
        return HStack(spacing: 2) {
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
}

// MARK: - Row Model

struct HoldingTableRow: Identifiable, Comparable {
    let holding: Holding
    let totalValue: Money
    let rates: any ExchangeRates

    var id: PersistentIdentifier { holding.persistentModelID }
    var ticker: String { holding.ticker }
    var quantityValue: Double { NSDecimalNumber(decimal: holding.quantity).doubleValue }
    var priceValue: Double { NSDecimalNumber(decimal: holding.currentPrice).doubleValue }
    var gainValue: Double { NSDecimalNumber(decimal: holding.gainLossPercent).doubleValue }
    var incomeValue: Double { NSDecimalNumber(decimal: holding.estimatedMonthlyIncomeNet()).doubleValue }
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
