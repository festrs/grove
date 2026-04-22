import Foundation
import SwiftData

@Observable
final class PortfolioViewModel {
    var selectedClass: AssetClassType?
    var portfolios: [Portfolio] = []
    var selectedPortfolio: Portfolio?
    var holdings: [Holding] = []
    var filteredHoldings: [Holding] = []
    var allocationByClass: [AssetClassAllocation] = []
    var summary: PortfolioSummary?
    var totalValueBRL: Decimal = 0
    var isLoading = false

    // Search result from AssetSearchView
    var selectedSearchResult: StockSearchResultDTO?

    // Sheets
    var showingAddDetails = false
    var showingEditPortfolio = false
    var showingNewPortfolio = false
    var holdingToRemove: Holding?

    func loadData(modelContext: ModelContext, exchangeRate: Decimal = 5.12) {
        let repo = PortfolioRepository(modelContext: modelContext)
        do {
            // Load all portfolios
            let descriptor = FetchDescriptor<Portfolio>(sortBy: [SortDescriptor(\.createdAt)])
            portfolios = try modelContext.fetch(descriptor)

            if selectedPortfolio == nil {
                selectedPortfolio = portfolios.first
            }

            // Load holdings for selected portfolio
            if let portfolio = selectedPortfolio {
                holdings = portfolio.holdings
            } else {
                holdings = try repo.fetchAllHoldings()
            }

            let classAlloc = selectedPortfolio?.classAllocations ?? [:]
            let summaryResult = repo.computeSummary(holdings: holdings, classAllocations: classAlloc, exchangeRate: exchangeRate)
            summary = summaryResult
            allocationByClass = summaryResult.allocationByClass
            totalValueBRL = summaryResult.totalValueBRL
            applyFilter()
        } catch {
            holdings = []
        }
    }

    func applyFilter() {
        if let selected = selectedClass {
            filteredHoldings = holdings.filter { $0.assetClass == selected }
        } else {
            filteredHoldings = holdings
        }
        filteredHoldings.sort { h1, h2 in
            let gap1 = h1.targetPercent - currentPercent(for: h1)
            let gap2 = h2.targetPercent - currentPercent(for: h2)
            return gap1 > gap2
        }
    }

    func selectClass(_ classType: AssetClassType?) {
        selectedClass = classType
        applyFilter()
    }

    func selectPortfolio(_ portfolio: Portfolio, modelContext: ModelContext) {
        selectedPortfolio = portfolio
        loadData(modelContext: modelContext)
    }

    func deleteHolding(_ holding: Holding, modelContext: ModelContext) {
        if holding.quantity > 0 {
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
        applyFilter()
    }

    func createPortfolio(name: String, modelContext: ModelContext) {
        let portfolio = Portfolio(name: name)
        modelContext.insert(portfolio)
        portfolios.append(portfolio)
        selectedPortfolio = portfolio
        loadData(modelContext: modelContext)
    }

    private func currentPercent(for holding: Holding) -> Decimal {
        guard totalValueBRL > 0 else { return 0 }
        let brlValue = holding.currency == .usd ? holding.currentValue * 5.12 : holding.currentValue
        return (brlValue / totalValueBRL) * 100
    }
}
