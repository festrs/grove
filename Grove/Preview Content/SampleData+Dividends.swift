import Foundation
import GroveDomain

enum SampleDividends {
    static func generate(for holdings: [Holding]) -> [DividendPayment] {
        var dividends: [DividendPayment] = []
        let calendar = Calendar.current

        for holding in holdings where holding.dividendYield > 0 {
            // Generate last 6 months of dividend payments
            let monthlyDividendPerShare = (holding.currentPrice * holding.dividendYield / 100) / 12

            for monthsAgo in 0..<6 {
                guard let paymentDate = calendar.date(byAdding: .month, value: -monthsAgo, to: .now) else { continue }
                guard let exDate = calendar.date(byAdding: .day, value: -15, to: paymentDate) else { continue }

                // FIIs pay monthly, others vary
                let shouldPay: Bool
                switch holding.assetClass {
                case .fiis:
                    shouldPay = true // monthly
                case .acoesBR:
                    shouldPay = monthsAgo % 3 == 0 // quarterly
                case .usStocks, .reits:
                    shouldPay = monthsAgo % 3 == 0 // quarterly
                default:
                    shouldPay = false
                }

                guard shouldPay else { continue }

                let multiplier: Decimal = holding.assetClass == .acoesBR ? 3 : (holding.assetClass == .fiis ? 1 : 3)
                let dividend = DividendPayment(
                    exDate: exDate,
                    paymentDate: paymentDate,
                    amountPerShare: monthlyDividendPerShare * multiplier,
                    taxTreatment: holding.assetClass.defaultTaxTreatment
                )
                dividend.holding = holding
                dividends.append(dividend)
            }
        }

        return dividends
    }
}
