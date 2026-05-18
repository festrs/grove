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
                primaryLine
                secondaryLine
            }
            statusIndicator
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var statusIndicator: some View {
        VStack(spacing: 2) {
            Image(systemName: holding.status.icon)
                .font(.system(size: 11))
            Text(holding.status.displayName)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(holding.status.color)
        .allowsHitTesting(false)
    }

    private var primaryLine: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(holding.displayTicker)
                .font(.system(.subheadline, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: Theme.Spacing.xs)
            Text(holding.currentValueMoney.formatted())
                .font(.system(.subheadline, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private var secondaryLine: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(holding.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: Theme.Spacing.xs)
            Text(row.allocation.formattedPercent())
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
