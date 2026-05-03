import Foundation
import SwiftData
import GroveDomain
import GroveRepositories

@Observable
final class PortfolioViewModel {
    var portfolios: [Portfolio] = []
    var selectedPortfolio: Portfolio?
    var holdings: [Holding] = []
    var allocationByClass: [AssetClassAllocation] = []
    var summary: PortfolioSummary?
    var totalValue: Money = .zero(in: .brl)
    var isLoading = false

    var showingEditPortfolio = false
    var showingNewPortfolio = false
    var holdingToRemove: Holding?

    func loadData(modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        let repo = PortfolioRepository(modelContext: modelContext)
        do {
            portfolios = try repo.fetchAllPortfolios()

            if selectedPortfolio == nil {
                selectedPortfolio = portfolios.first
            }

            if let portfolio = selectedPortfolio {
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

    func selectPortfolio(_ portfolio: Portfolio, modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        selectedPortfolio = portfolio
        loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
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

    func createPortfolio(name: String, modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        let portfolio = Portfolio(name: name)
        modelContext.insert(portfolio)
        portfolios.append(portfolio)
        selectedPortfolio = portfolio
        loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
    }
}
