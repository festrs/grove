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

    func loadData(modelContext: ModelContext) {
        isLoading = true
        error = nil

        let portfolioRepo = PortfolioRepository(modelContext: modelContext)
        let dividendRepo = DividendRepository(modelContext: modelContext)

        do {
            let holdings = try portfolioRepo.fetchAllHoldings()
            let settings = try portfolioRepo.fetchSettings()

            let computedSummary = portfolioRepo.computeSummary(holdings: holdings, classAllocations: settings.classAllocations)
            summary = computedSummary

            // TODO: Enable when push notifications are ready
            // Task { await NotificationCoordinator.handleDriftCheck(allocations: computedSummary.allocationByClass) }

            projection = IncomeProjector.project(
                holdings: holdings,
                incomeGoal: settings.monthlyIncomeGoal
            )

            // TODO: Enable when push notifications are ready
            // if let progress = projection?.progressPercent {
            //     Task { await NotificationCoordinator.handleMilestoneCheck(progressPercent: progress) }
            // }

            // Dashboard only renders ticker + class-drift %, so the amount is
            // a placeholder for ranking. Use the portfolio total when present,
            // otherwise fall back to the income goal so a fresh portfolio
            // (every holding still at quantity 0) still gets a ranked preview.
            let rankingAmount = max(
                computedSummary.totalValue,
                settings.monthlyIncomeGoal,
                1000
            )
            topSuggestions = try RebalancingEngine.suggestions(
                modelContext: modelContext,
                investmentAmount: rankingAmount
            )

            nextDividends = try dividendRepo.upcomingDividends(days: 30)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
