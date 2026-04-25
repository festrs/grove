import SwiftUI

struct HoldingRow: View {
    let holding: Holding
    let totalValue: Decimal
    var exchangeRate: Decimal = 5.12

    private var brlValue: Decimal {
        holding.currency == .usd ? holding.currentValue * exchangeRate : holding.currentValue
    }

    private var currentPercent: Decimal {
        guard totalValue > 0 else { return 0 }
        return (brlValue / totalValue) * 100
    }

    private var gainLoss: Decimal { holding.gainLossPercent }

    var body: some View {
        HStack(spacing: 12) {
            // Left: icon + ticker + name
            HStack(spacing: 10) {
                Circle()
                    .fill(holding.assetClass.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: holding.assetClass.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(holding.assetClass.color)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.ticker)
                        .font(.system(.body, weight: .semibold))
                    Text("\(holding.quantity) cotas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Right: price + gain/loss badge
            VStack(alignment: .trailing, spacing: 4) {
                Text(holding.currentPrice.formatted(as: holding.currency))
                    .font(.system(.body, weight: .semibold))

                HStack(spacing: 2) {
                    Image(systemName: gainLoss >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(gainLoss.formattedPercent())
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    gainLoss >= 0 ? Color.tqPositive : Color.tqNegative,
                    in: RoundedRectangle(cornerRadius: 6)
                )
            }
        }
        .padding(.vertical, 10)
    }
}
