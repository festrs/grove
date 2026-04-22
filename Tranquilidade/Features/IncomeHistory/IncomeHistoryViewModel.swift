import Foundation
import SwiftData

@Observable
final class IncomeHistoryViewModel {
    var incomeByClass: [(assetClass: AssetClassType, annual: Decimal)] = []
    var totalAnnualBRL: Decimal = 0
    var monthlyIncomeBRL: Decimal = 0
    var taxBreakdown: TaxBreakdownResult?
    var isLoading = false

    func loadData(modelContext: ModelContext) {
        isLoading = true
        defer { isLoading = false }

        do {
            let holdings = try HoldingRepository(modelContext: modelContext).fetchAll()
            var grossByClass: [AssetClassType: Decimal] = [:]

            for h in holdings {
                let monthlyGross = h.estimatedMonthlyIncome
                let brlMonthly = h.currency == .usd ? monthlyGross * 5.12 : monthlyGross
                grossByClass[h.assetClass, default: 0] += brlMonthly
            }

            taxBreakdown = TaxCalculator.taxBreakdown(grossByClass: grossByClass)

            incomeByClass = grossByClass.map { (assetClass: $0.key, annual: $0.value * 12) }
                .sorted { $0.annual > $1.annual }

            totalAnnualBRL = incomeByClass.reduce(Decimal.zero) { $0 + $1.annual }
            monthlyIncomeBRL = totalAnnualBRL / 12
        } catch {
            incomeByClass = []
        }
    }
}
