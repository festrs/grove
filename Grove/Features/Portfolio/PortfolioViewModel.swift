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
        let scoped = selectedClass.map { sel in holdings.filter { $0.assetClass == sel } } ?? holdings
        filteredHoldings = scoped.sortedByAllocationGap(
            totalValue: totalValue,
            in: displayCurrency,
            rates: rates
        )
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

    /// Add a search result directly to the portfolio as a `.estudo` (study)
    /// holding — no transaction, no quantity. The user can buy into it later
    /// via the Buy button on the holding detail.
    @discardableResult
    func addStudyHolding(
        from result: StockSearchResultDTO,
        modelContext: ModelContext,
        backendService: any BackendServiceProtocol
    ) -> Bool {
        guard Holding.canAddMore(modelContext: modelContext) else { return false }

        let assetClass = AssetClassType.detect(from: result.symbol, apiType: result.type) ?? .acoesBR
        let price = result.priceDecimal ?? 0

        let holding = Holding(
            ticker: result.symbol,
            displayName: result.name ?? result.symbol,
            currentPrice: price,
            assetClass: assetClass,
            status: .estudo
        )
        holding.sector = result.sector
        holding.logoURL = result.logo

        if let portfolio = selectedPortfolio {
            holding.portfolio = portfolio
        } else {
            var descriptor = FetchDescriptor<Portfolio>(sortBy: [SortDescriptor(\.createdAt)])
            descriptor.fetchLimit = 1
            if let p = try? modelContext.fetch(descriptor).first {
                holding.portfolio = p
            } else {
                let p = Portfolio()
                modelContext.insert(p)
                holding.portfolio = p
            }
        }
        modelContext.insert(holding)

        let sym = holding.ticker
        let cls = assetClass.rawValue
        let bootstrap = TickerBootstrapService()
        Task { @MainActor in
            try? await backendService.trackSymbol(symbol: sym, assetClass: cls)
            await bootstrap.bootstrap(holdings: [holding], backendService: backendService)
            try? modelContext.save()
        }

        return true
    }

}
