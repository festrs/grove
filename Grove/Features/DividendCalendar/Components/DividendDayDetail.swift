import SwiftUI

struct DividendDayDetail: View {
    let dividends: [DividendPayment]

    private var total: Decimal {
        dividends.reduce(Decimal.zero) { $0 + $1.netAmount }
    }

    var body: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Daily Dividends")
                        .font(.headline)
                    Spacer()
                    Text(total.formattedBRL())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.tqAccentGreen)
                }

                ForEach(dividends, id: \.paymentDate) { dividend in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dividend.holding?.ticker ?? "—")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(dividend.holding?.displayName ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(dividend.netAmount.formattedBRL())
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if dividend.withholdingTax > 0 {
                                Text("IR: \(dividend.withholdingTax.formattedBRL())")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if dividend.paymentDate != dividends.last?.paymentDate {
                        Divider()
                    }
                }
            }
        }
    }
}
