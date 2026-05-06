import Foundation
import SwiftData
import GroveDomain
import GroveRepositories

@Observable
final class PortfolioViewModel {
    var portfolio: Portfolio?
    var holdings: [Holding] = []
    var allocationByClass: [AssetClassAllocation] = []
    var summary: PortfolioSummary?
    var totalValue: Money = .zero(in: .brl)
    var isLoading = false

    var showingEditPortfolio = false
    var holdingToRemove: Holding?

    func loadData(modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        isLoading = true
        defer { isLoading = false }
        let repo = PortfolioRepository(modelContext: modelContext)
        do {
            portfolio = try repo.fetchDefaultPortfolio()

            if let portfolio {
                holdings = portfolio.holdings
            } else {
                holdings = try repo.fetchAllHoldings()
            }

            let settings = try repo.fetchSettings()
            let summaryResult = repo.computeSummary(
                holdings: holdings,
                classAllocations: settings.classAllocations,
                displayCurrency: displayCurrency,
                rates: rates
            )
            summary = summaryResult
            allocationByClass = summaryResult.allocationByClass
            totalValue = summaryResult.totalValue
        } catch {
            holdings = []
        }
    }

    func deleteHolding(_ holding: Holding, modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        if holding.hasPosition {
            let contribution = Contribution(
                date: .now,
                amount: -(holding.quantity * holding.currentPrice),
                shares: -holding.quantity,
                pricePerShare: holding.currentPrice
            )
            contribution.holding = holding
            modelContext.insert(contribution)
        }
        modelContext.delete(holding)
        holdings.removeAll { $0.ticker == holding.ticker }
    }
}
