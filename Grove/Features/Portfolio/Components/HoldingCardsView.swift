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

    @Environment(\.rates) private var rates
    @Binding var sortOrder: [KeyPathComparator<HoldingTableRow>]

    private var sortedRows: [HoldingTableRow] {
        holdings
            .map { HoldingTableRow(holding: $0, totalValue: totalValue, rates: rates) }
            .sorted(using: sortOrder)
    }

    var body: some View {
        LazyVStack(spacing: Theme.Spacing.xs) {
            ForEach(sortedRows) { row in
                HoldingCardView(row: row)
                    .contentShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    .onTapGesture {
                        onSelect(row.holding.persistentModelID)
                    }
                    .contextMenu {
                        holdingContextMenu(row.holding)
                    }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
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

    private var holding: Holding { row.holding }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                primaryLine
                secondaryLine
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Color.tqCardBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
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
            gainPill
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

    private var gainPill: some View {
        let gain = holding.gainLossPercent
        return Text(gain.formattedPercent())
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                gain >= 0 ? Color.tqPositive : Color.tqNegative,
                in: Capsule()
            )
    }
}
