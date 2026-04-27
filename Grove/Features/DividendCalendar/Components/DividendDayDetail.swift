import SwiftUI
import GroveDomain

struct DividendDayDetail: View {
    let dividends: [DividendPayment]
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    private var total: Money {
        dividends.map { $0.netAmountMoney }.sum(in: displayCurrency, using: rates)
    }

    var body: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Daily Dividends")
                        .font(.headline)
                    Spacer()
                    Text(total.formatted())
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
                            Text(dividend.netAmountMoney.formatted())
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if dividend.withholdingTax > 0 {
                                Text("IR: \(dividend.withholdingTaxMoney.formatted())")
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
