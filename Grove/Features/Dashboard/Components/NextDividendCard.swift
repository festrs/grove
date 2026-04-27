import SwiftUI
import SwiftData
import GroveDomain

struct NextDividendCard: View {
    let dividends: [DividendPayment]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "dd MMM"
        return formatter
    }()

    var body: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Color.tqAccentGreen)
                    Text("Upcoming Dividends")
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                }

                if dividends.isEmpty {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.tqSecondaryText)
                        Text("No dividends scheduled")
                            .font(.system(size: Theme.FontSize.body))
                            .foregroundStyle(Color.tqSecondaryText)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                } else {
                    ForEach(dividends.prefix(5)) { dividend in
                        dividendRow(dividend)

                        if dividend.id != dividends.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dividendRow(_ dividend: DividendPayment) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(dividend.holding?.ticker ?? "---")
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))

                    if dividend.isInformational {
                        Text("studying")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.tqAccentBlue.opacity(0.18), in: Capsule())
                            .foregroundStyle(Color.tqAccentBlue)
                    }
                }

                Text(Self.dateFormatter.string(from: dividend.paymentDate))
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Color.tqSecondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText(dividend))
                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                    .foregroundStyle(amountColor(dividend))

                Text(amountCaption(dividend))
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Color.tqSecondaryText)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func amountText(_ dividend: DividendPayment) -> String {
        dividend.isInformational
            ? dividend.amountPerShareMoney.formatted()
            : dividend.netAmountMoney.formatted()
    }

    private func amountColor(_ dividend: DividendPayment) -> Color {
        dividend.isInformational ? Color.tqAccentBlue : Color.tqPositive
    }

    private func amountCaption(_ dividend: DividendPayment) -> String {
        dividend.isInformational ? "per share" : "net"
    }
}

#Preview("Com dividendos") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Holding.self, DividendPayment.self, Portfolio.self, UserSettings.self,
        configurations: config
    )
    let context = container.mainContext

    let holding1 = Holding(
        ticker: "KNRI11",
        displayName: "Kinea Renda",
        quantity: 50,
        currentPrice: 155,
        dividendYield: 8.0,
        assetClass: .fiis,
        targetPercent: 20
    )
    context.insert(holding1)

    let div1 = DividendPayment(
        exDate: Calendar.current.date(byAdding: .day, value: 5, to: .now)!,
        paymentDate: Calendar.current.date(byAdding: .day, value: 12, to: .now)!,
        amountPerShare: 0.95,
        quantity: 50
    )
    div1.holding = holding1
    context.insert(div1)

    let holding2 = Holding(
        ticker: "BTLG11",
        displayName: "BTG Logistica",
        quantity: 30,
        currentPrice: 98,
        dividendYield: 9.0,
        assetClass: .fiis,
        targetPercent: 10
    )
    context.insert(holding2)

    let div2 = DividendPayment(
        exDate: Calendar.current.date(byAdding: .day, value: 10, to: .now)!,
        paymentDate: Calendar.current.date(byAdding: .day, value: 20, to: .now)!,
        amountPerShare: 0.78,
        quantity: 30
    )
    div2.holding = holding2
    context.insert(div2)

    return NextDividendCard(dividends: [div1, div2])
        .padding()
        .modelContainer(container)
}

#Preview("Sem dividendos") {
    NextDividendCard(dividends: [])
        .padding()
}
