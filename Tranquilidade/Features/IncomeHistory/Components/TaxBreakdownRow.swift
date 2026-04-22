import SwiftUI

struct TaxBreakdownRow: View {
    let detail: TaxBreakdownDetail

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
                Text(detail.gross.formattedBRL())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if detail.tax > 0 {
                    Text("-\(detail.tax.formattedBRL())")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                Text(detail.net.formattedBRL())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.tqAccentGreen)
            }
        }
    }
}
