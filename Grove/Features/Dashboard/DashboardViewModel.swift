import Foundation
import SwiftData
import GroveDomain
import GroveServices
import GroveRepositories

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

            // Contribution: prefer the user's declared capacity from the
            // Freedom Plan; fall back to a small placeholder so first-run
            // users (who haven't filled the plan yet) still see a non-empty
            // projection instead of "—".
            let capacity = settings.monthlyContributionCapacityMoney
            let contribution = capacity.amount > 0
                ? capacity
                : Money(amount: 1_000, currency: displayCurrency)
            let targetYear: Int? = settings.targetFIYear > 0 ? settings.targetFIYear : nil

            projection = IncomeProjector.project(
                holdings: holdings,
                incomeGoal: settings.monthlyIncomeGoalMoney,
                monthlyContribution: contribution,
                displayCurrency: displayCurrency,
                rates: rates,
                targetYear: targetYear
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
