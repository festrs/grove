import SwiftUI
import GroveDomain
import GroveServices

struct TaxBreakdownRow: View {
    let detail: MoneyTaxBreakdownDetail

    var body: some View {
        HStack {
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(detail.assetClass.color)
                    .frame(width: 8, height: 8)
                Text(detail.assetClass.displayName)
                    .font(.subheadline)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(detail.gross.formatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if detail.tax.amount > 0 {
                    Text("-\(detail.tax.formatted())")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                Text(detail.net.formatted())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.tqAccentGreen)
            }
        }
    }
}
