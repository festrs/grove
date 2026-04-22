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
            let portfolios = try portfolioRepo.fetchAllPortfolios()

            // Merge class allocations from all portfolios
            var mergedAlloc: [AssetClassType: Double] = [:]
            for p in portfolios {
                for (ct, pct) in p.classAllocations {
                    mergedAlloc[ct, default: 0] += pct
                }
            }

            let computedSummary = portfolioRepo.computeSummary(holdings: holdings, classAllocations: mergedAlloc)
            summary = computedSummary

            projection = IncomeProjector.project(
                holdings: holdings,
                incomeGoal: settings.monthlyIncomeGoal
            )

            topSuggestions = try RebalancingEngine.suggestions(
                modelContext: modelContext,
                investmentAmount: computedSummary.totalValueBRL
            )

            nextDividends = try dividendRepo.upcomingDividends(days: 30)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
