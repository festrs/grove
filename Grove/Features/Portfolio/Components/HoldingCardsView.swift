import SwiftUI
import SwiftData
import GroveDomain

/// Compact-layout (iPhone) holdings list rendered as a vertical stack of
/// dense two-line rows. Line 1: class icon · ticker · value · gain pill.
/// Line 2: company name · allocation %. Status changes and buy/sell live
/// in the long-press context menu; full position breakdown and monthly
/// income live on the holding detail screen.
struct HoldingCardsView: View {
    let holdings: [Holding]
    let totalValue: Money
    var onSelect: (PersistentIdentifier) -> Void = { _ in }
    var onChangeStatus: (Holding, HoldingStatus) -> Void = { _, _ in }
    var onBuy: (Holding) -> Void = { _ in }
    var onSell: (Holding) -> Void = { _ in }
    var onRemove: (Holding) -> Void = { _ in }
    var isEditing: Bool = false
    var selection: Binding<Set<PersistentIdentifier>> = .constant([])

    @Environment(\.rates) private var rates
    @Binding var sortOrder: [KeyPathComparator<HoldingTableRow>]

    private var sortedRows: [HoldingTableRow] {
        holdings
            .map { HoldingTableRow(holding: $0, totalValue: totalValue, rates: rates) }
            .sorted(using: sortOrder)
    }

    var body: some View {
        // Single grouped card with hairline dividers — matches the
        // class-table pattern on the portfolio root so both screens read as
        // continuous lists. Per-row card backgrounds were previously creating
        // visible gaps between rows that don't exist on the root.
        LazyVStack(spacing: 0) {
            ForEach(Array(sortedRows.enumerated()), id: \.element.id) { index, row in
                let id = row.holding.persistentModelID
                let isSelected = selection.wrappedValue.contains(id)
                HStack(spacing: Theme.Spacing.sm) {
                    if isEditing {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                            .padding(.leading, Theme.Spacing.md)
                    }
                    HoldingCardView(row: row, showsChevron: !isEditing)
                }
                .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isEditing {
                        toggle(id)
                    } else {
                        onSelect(id)
                    }
                }
                .contextMenu {
                    if !isEditing {
                        holdingContextMenu(row.holding)
                    }
                }
                if index < sortedRows.count - 1 {
                    Divider().opacity(0.4)
                }
            }
        }
        .background(Color.tqCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .padding(.horizontal, Theme.Spacing.md)
    }

    private func toggle(_ id: PersistentIdentifier) {
        var set = selection.wrappedValue
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        selection.wrappedValue = set
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

// MARK: - Card

struct HoldingCardView: View {
    let row: HoldingTableRow
    var showsChevron: Bool = true

    private var holding: Holding { row.holding }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.displayTicker)
                    .font(.system(.subheadline, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: Theme.Spacing.xs) {
                    Text(holding.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(row.allocation.formattedPercent())
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if holding.quantity > 0 {
                        Text(verbatim: "· \(formattedQuantity)")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: Theme.Spacing.xs)
            VStack(alignment: .trailing, spacing: 2) {
                Text(holding.currentValueMoney.formatted())
                    .font(.system(.subheadline, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                statusIndicator
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var formattedQuantity: String {
        let d = NSDecimalNumber(decimal: holding.quantity).doubleValue
        if d >= 1, d == d.rounded(.towardZero), d < 1_000_000 {
            return "\(Int(d))"
        }
        let formatter = NumberFormatter()
        formatter.maximumSignificantDigits = 4
        formatter.minimumSignificantDigits = 1
        formatter.usesSignificantDigits = true
        return formatter.string(from: NSDecimalNumber(decimal: holding.quantity)) ?? "\(holding.quantity)"
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: holding.status.icon)
                .font(.system(size: 11))
            Text(holding.status.displayName)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(holding.status.color)
        .allowsHitTesting(false)
    }
}

#Preview("HoldingCardsView") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Portfolio.self, Holding.self, DividendPayment.self, GroveDomain.Transaction.self, UserSettings.self,
        configurations: config
    )
    let ctx = container.mainContext

    let portfolio = Portfolio(name: "Meu Portfolio")
    ctx.insert(portfolio)

    let holdings: [Holding] = [.itub3, .petr4, .wege3, .btlg11, .aapl, .nvda, .o, .btc]
    for h in holdings {
        h.portfolio = portfolio
        ctx.insert(h)
    }

    let totalAmount = holdings.reduce(Decimal(0)) { $0 + $1.currentValueMoney.amount }

    struct PreviewWrapper: View {
        let holdings: [Holding]
        let totalValue: Money
        @State private var sortOrder: [KeyPathComparator<HoldingTableRow>] = [
            KeyPathComparator(\HoldingTableRow.ticker)
        ]
        @State private var selection: Set<PersistentIdentifier> = []

        var body: some View {
            ScrollView {
                HoldingCardsView(
                    holdings: holdings,
                    totalValue: totalValue,
                    selection: $selection,
                    sortOrder: $sortOrder
                )
                .padding(.vertical, Theme.Spacing.md)
            }
        }
    }

    return PreviewWrapper(
        holdings: holdings,
        totalValue: Money(amount: totalAmount, currency: .brl)
    )
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
