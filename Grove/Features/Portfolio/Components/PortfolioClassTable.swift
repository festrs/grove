import SwiftUI
import GroveDomain
import GroveRepositories

/// Class-first table that drives the new portfolio hierarchy. One row per
/// asset class — value, current/target %, drift, holdings count. Tapping a
/// row asks the parent to drill into that class's holdings.
struct PortfolioClassTable: View {
    let allocations: [AssetClassAllocation]
    let holdings: [Holding]
    let onSelect: (AssetClassType) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(allocations) { alloc in
                Button {
                    onSelect(alloc.assetClass)
                } label: {
                    PortfolioClassRow(
                        allocation: alloc,
                        holdingsCount: holdings.filter { $0.assetClass == alloc.assetClass }.count
                    )
                }
                .buttonStyle(.plain)
                Divider().opacity(0.4)
            }
        }
    }
}

struct PortfolioClassRow: View {
    let allocation: AssetClassAllocation
    let holdingsCount: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(allocation.assetClass.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: allocation.assetClass.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(allocation.assetClass.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(allocation.assetClass.displayName)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(holdingsCount == 1 ? "1 ticker" : "\(holdingsCount) tickers")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Theme.Spacing.sm)

            VStack(alignment: .trailing, spacing: 2) {
                Text(allocation.currentValue.formatted())
                    .font(.system(.body, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                allocationLabel
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var allocationLabel: some View {
        let current = allocation.currentPercent.formattedPercent(decimals: 0)
        let target = allocation.targetPercent.formattedPercent(decimals: 0)
        if allocation.targetPercent > 0 {
            HStack(spacing: 4) {
                Text("\(current) / \(target)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                driftIndicator
            }
        } else {
            Text(current)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var driftIndicator: some View {
        let absDrift = abs(NSDecimalNumber(decimal: allocation.drift).doubleValue)
        if absDrift >= 1 {
            let isOver = allocation.drift > 0
            Image(systemName: isOver ? "arrow.up" : "arrow.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isOver ? Color.tqNegative : Color.tqAccentGreen)
        }
    }
}

#Preview {
    PortfolioClassTable(
        allocations: [
            AssetClassAllocation(assetClass: .acoesBR, currentValue: Money(amount: 5000, currency: .brl), currentPercent: 23, targetPercent: 30, drift: -7),
            AssetClassAllocation(assetClass: .fiis, currentValue: Money(amount: 2000, currency: .brl), currentPercent: 9, targetPercent: 20, drift: -11),
            AssetClassAllocation(assetClass: .usStocks, currentValue: Money(amount: 7000, currency: .brl), currentPercent: 31, targetPercent: 25, drift: 6),
        ],
        holdings: [],
        onSelect: { _ in }
    )
    .padding()
    .background(Color.tqBackground)
    .preferredColorScheme(.dark)
}
