import SwiftUI
import GroveDomain

struct HoldingRow: View {
    let holding: Holding
    let totalValue: Money

    private var gainLoss: Decimal { holding.gainLossPercent }

    var body: some View {
        HStack(spacing: 12) {
            TQTickerRow(
                ticker: holding.displayTicker,
                subtitle: "\(holding.quantity) shares",
                assetClass: holding.assetClass,
                showIcon: true
            )

            VStack(alignment: .trailing, spacing: 4) {
                Text(holding.priceMoney.formatted())
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
