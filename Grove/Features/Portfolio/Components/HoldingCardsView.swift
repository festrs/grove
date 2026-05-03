import SwiftUI
import SwiftData
import GroveDomain

/// Compact-layout (iPhone) holdings list rendered as a vertical stack of
/// cards. Each card shows the same information as `HoldingsListView`'s
/// row but laid out for a narrow screen — ticker + status on top,
/// position and value on the next line, then a footer strip with the
/// gain pill, allocation, and monthly income.
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
        LazyVStack(spacing: Theme.Spacing.sm) {
            ForEach(sortedRows) { row in
                HoldingCardView(
                    row: row,
                    onChangeStatus: onChangeStatus
                )
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
    var onChangeStatus: (Holding, HoldingStatus) -> Void = { _, _ in }

    private var holding: Holding { row.holding }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            header
            Divider().opacity(0.3)
            footer
        }
        .padding(Theme.Spacing.md)
        .background(Color.tqCardBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Circle()
                .fill(holding.assetClass.color.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: holding.assetClass.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(holding.assetClass.color)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(holding.displayTicker)
                    .font(.system(.headline, weight: .semibold))
                    .lineLimit(1)
                Text(holding.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusMenu

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                metric(
                    label: String(localized: "Position"),
                    value: "\(holding.quantity) × \(holding.priceMoney.formatted())",
                    alignment: .leading
                )
                Spacer(minLength: 0)
                metric(
                    label: String(localized: "Value"),
                    value: holding.currentValueMoney.formatted(),
                    alignment: .trailing
                )
            }

            bottomStrip
        }
    }

    private var bottomStrip: some View {
        HStack(spacing: Theme.Spacing.sm) {
            gainPill
            allocationChip
            Spacer(minLength: 0)
            incomeLabel
        }
    }

    private func metric(label: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(verbatim: label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.system(.subheadline, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private var gainPill: some View {
        let gain = holding.gainLossPercent
        return HStack(spacing: 2) {
            Image(systemName: gain >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(gain.formattedPercent())
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            gain >= 0 ? Color.tqPositive : Color.tqNegative,
            in: Capsule()
        )
    }

    private var allocationChip: some View {
        Text(row.allocation.formattedPercent())
            .font(.system(size: 12, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.tqBackground, in: Capsule())
    }

    private var incomeLabel: some View {
        HStack(spacing: 4) {
            Text(holding.estimatedMonthlyIncomeNetMoney.formatted())
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.tqAccentGreen)
            Text("/mo")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var statusMenu: some View {
        Menu {
            ForEach(HoldingStatus.allCases) { status in
                Button {
                    onChangeStatus(holding, status)
                } label: {
                    Label(status.displayName, systemImage: status.icon)
                }
                .disabled(holding.status == status)
            }
        } label: {
            TQStatusBadge(status: holding.status)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
