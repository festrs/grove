import Foundation
import SwiftData
import GroveDomain
import GroveServices

@Observable
final class IncomeHistoryViewModel {
    var incomeByClass: [AnnualIncomeByClass] = []
    var totalAnnual: Money = .zero(in: .brl)
    var monthlyIncome: Money = .zero(in: .brl)
    var taxBreakdown: MoneyTaxBreakdown?
    var isLoading = false

    func loadData(modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        isLoading = true
        defer { isLoading = false }

        do {
            let holdings = try HoldingRepository(modelContext: modelContext).fetchAll()

            incomeByClass = IncomeProjector.annualIncomeByClass(
                holdings: holdings,
                in: displayCurrency,
                rates: rates
            )

            let monthlyGrossByClass = Dictionary(
                uniqueKeysWithValues: incomeByClass.map { ($0.assetClass, $0.annual / 12) }
            )
            taxBreakdown = TaxCalculator.taxBreakdown(
                grossByClass: monthlyGrossByClass,
                displayCurrency: displayCurrency,
                rates: rates
            )

            totalAnnual = incomeByClass.map { $0.annual }.sum(in: displayCurrency, using: rates)
            monthlyIncome = totalAnnual / 12
        } catch {
            incomeByClass = []
        }
    }
}
