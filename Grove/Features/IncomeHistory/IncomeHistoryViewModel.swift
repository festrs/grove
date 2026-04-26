import Foundation
import SwiftData

@Observable
final class IncomeHistoryViewModel {
    var incomeByClass: [(assetClass: AssetClassType, annual: Money)] = []
    var totalAnnual: Money = .zero(in: .brl)
    var monthlyIncome: Money = .zero(in: .brl)
    var taxBreakdown: MoneyTaxBreakdown?
    var isLoading = false

    func loadData(modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        isLoading = true
        defer { isLoading = false }

        do {
            let holdings = try HoldingRepository(modelContext: modelContext).fetchAll()
            var grossByClass: [AssetClassType: Money] = [:]

            for h in holdings {
                let monthlyGross = h.estimatedMonthlyIncomeMoney
                grossByClass[h.assetClass] = (grossByClass[h.assetClass] ?? .zero(in: h.currency)) + monthlyGross
            }

            taxBreakdown = TaxCalculator.taxBreakdown(
                grossByClass: grossByClass,
                displayCurrency: displayCurrency,
                rates: rates
            )

            incomeByClass = grossByClass.map { (assetClass: $0.key, annual: $0.value * 12) }
                .sorted { lhs, rhs in
                    lhs.annual.converted(to: displayCurrency, using: rates).amount
                        > rhs.annual.converted(to: displayCurrency, using: rates).amount
                }

            totalAnnual = incomeByClass.map { $0.annual }.sum(in: displayCurrency, using: rates)
            monthlyIncome = totalAnnual / 12
        } catch {
            incomeByClass = []
        }
    }
}
