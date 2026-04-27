import Foundation
import SwiftData
import GroveDomain
import GroveRepositories

@Observable
final class PortfolioViewModel {
    var selectedClass: AssetClassType?
    var portfolios: [Portfolio] = []
    var selectedPortfolio: Portfolio?
    var holdings: [Holding] = []
    var filteredHoldings: [Holding] = []
    var allocationByClass: [AssetClassAllocation] = []
    var summary: PortfolioSummary?
    var totalValue: Money = .zero(in: .brl)
    var isLoading = false

    var selectedSearchResult: StockSearchResultDTO?

    var showingAddDetails = false
    var showingEditPortfolio = false
    var showingNewPortfolio = false
    var holdingToRemove: Holding?

    func loadData(modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        let repo = PortfolioRepository(modelContext: modelContext)
        do {
            let descriptor = FetchDescriptor<Portfolio>(sortBy: [SortDescriptor(\.createdAt)])
            portfolios = try modelContext.fetch(descriptor)

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
            applyFilter(displayCurrency: displayCurrency, rates: rates)
        } catch {
            holdings = []
        }
    }

    func applyFilter(displayCurrency: Currency, rates: any ExchangeRates) {
        if let selected = selectedClass {
            filteredHoldings = holdings.filter { $0.assetClass == selected }
        } else {
            filteredHoldings = holdings
        }
        filteredHoldings.sort { h1, h2 in
            let gap1 = h1.targetPercent - currentPercent(for: h1, displayCurrency: displayCurrency, rates: rates)
            let gap2 = h2.targetPercent - currentPercent(for: h2, displayCurrency: displayCurrency, rates: rates)
            return gap1 > gap2
        }
    }

    func selectClass(_ classType: AssetClassType?, displayCurrency: Currency, rates: any ExchangeRates) {
        selectedClass = classType
        applyFilter(displayCurrency: displayCurrency, rates: rates)
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
        applyFilter(displayCurrency: displayCurrency, rates: rates)
    }

    func createPortfolio(name: String, modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        let portfolio = Portfolio(name: name)
        modelContext.insert(portfolio)
        portfolios.append(portfolio)
        selectedPortfolio = portfolio
        loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
    }

    private func currentPercent(for holding: Holding, displayCurrency: Currency, rates: any ExchangeRates) -> Decimal {
        guard totalValue.amount > 0 else { return 0 }
        let displayValue = holding.currentValueMoney.converted(to: displayCurrency, using: rates).amount
        return (displayValue / totalValue.amount) * 100
    }
}
