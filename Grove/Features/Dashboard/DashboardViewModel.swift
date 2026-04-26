import Foundation
import SwiftData

@Observable
final class DashboardViewModel {
    var summary: PortfolioSummary?
    var projection: IncomeProjection?
    var topSuggestions: [RebalancingSuggestion] = []
    var nextDividends: [DividendPayment] = []
    var isLoading = false
    var error: String?

    func loadData(modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        isLoading = true
        error = nil

        let portfolioRepo = PortfolioRepository(modelContext: modelContext)
        let dividendRepo = DividendRepository(modelContext: modelContext)

        do {
            let holdings = try portfolioRepo.fetchAllHoldings()
            let settings = try portfolioRepo.fetchSettings()

            let computedSummary = portfolioRepo.computeSummary(
                holdings: holdings,
                classAllocations: settings.classAllocations,
                displayCurrency: displayCurrency,
                rates: rates
            )
            summary = computedSummary

            projection = IncomeProjector.project(
                holdings: holdings,
                incomeGoal: settings.monthlyIncomeGoalMoney,
                monthlyContribution: Money(amount: 5_000, currency: displayCurrency),
                displayCurrency: displayCurrency,
                rates: rates
            )

            let totalValueAmount = computedSummary.totalValue.amount
            let goalAmount = settings.monthlyIncomeGoalMoney.converted(to: displayCurrency, using: rates).amount
            let rankingAmountValue = max(totalValueAmount, goalAmount, 1000)
            let rankingAmount = Money(amount: rankingAmountValue, currency: displayCurrency)
            topSuggestions = try RebalancingEngine.suggestions(
                modelContext: modelContext,
                investmentAmount: rankingAmount,
                rates: rates
            )

            nextDividends = try dividendRepo.upcomingDividends(days: 30)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
