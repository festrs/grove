import Foundation
import SwiftData
import GroveDomain
import GroveRepositories

/// Backs `AssetClassHoldingsView`. Owns the class-scoped holdings list,
/// the inline search debouncer, and the no-results "custom ticker" path.
///
/// Custom tickers are local-only — we set `isCustom = true` so the sync
/// service and bootstrap layer never query the backend for them. They
/// start as `.estudo` with zero price; the user fills in details from
/// `HoldingDetailView`.
@Observable
@MainActor
final class AssetClassHoldingsViewModel {
    let assetClass: AssetClassType

    var holdings: [Holding] = []
    var classTotalValue: Money = .zero(in: .brl)
    var classCurrentPercent: Decimal = 0
    var classTargetPercent: Decimal = 0

    // Search & add state
    var searchText: String = ""
    var debouncer = SearchDebouncer()
    var selectedSearchResult: StockSearchResultDTO?
    var showingAddDetails = false
    var holdingToBuy: Holding?
    var holdingToSell: Holding?
    var holdingToRemove: Holding?
    var errorMessage: String?

    init(assetClass: AssetClassType) {
        self.assetClass = assetClass
    }

    // MARK: - Load

    func loadData(
        portfolio: Portfolio?,
        modelContext: ModelContext,
        displayCurrency: Currency,
        rates: any ExchangeRates
    ) {
        let repo = PortfolioRepository(modelContext: modelContext)
        do {
            let allHoldings: [Holding]
            if let portfolio {
                allHoldings = portfolio.holdings
            } else {
                allHoldings = try repo.fetchAllHoldings()
            }
            let scoped = allHoldings.filter { $0.assetClass == assetClass }
            self.holdings = scoped.sortedByAllocationGap(
                totalValue: scoped.map(\.currentValueMoney).sum(in: displayCurrency, using: rates),
                in: displayCurrency,
                rates: rates
            )

            let settings = try repo.fetchSettings()
            let summary = repo.computeSummary(
                holdings: allHoldings,
                classAllocations: settings.classAllocations,
                displayCurrency: displayCurrency,
                rates: rates
            )
            if let alloc = summary.allocationByClass.first(where: { $0.assetClass == assetClass }) {
                classTotalValue = alloc.currentValue
                classCurrentPercent = alloc.currentPercent
                classTargetPercent = alloc.targetPercent
            } else {
                classTotalValue = .zero(in: displayCurrency)
                classCurrentPercent = 0
                classTargetPercent = 0
            }
        } catch {
            holdings = []
        }
    }

    // MARK: - Search

    func isAlreadyAdded(_ symbol: String) -> Bool {
        holdings.contains { $0.ticker.uppercased() == symbol.uppercased() }
    }

    func handleSearchAdd(_ result: StockSearchResultDTO) {
        selectedSearchResult = result
        showingAddDetails = true
    }

    func handleSearchRemove(
        _ result: StockSearchResultDTO,
        modelContext: ModelContext,
        portfolio: Portfolio?,
        displayCurrency: Currency,
        rates: any ExchangeRates
    ) {
        let upper = result.symbol.uppercased()
        guard let holding = holdings.first(where: { $0.ticker.uppercased() == upper }) else { return }
        deleteHolding(
            holding,
            modelContext: modelContext,
            portfolio: portfolio,
            displayCurrency: displayCurrency,
            rates: rates
        )
    }

    // MARK: - Custom ticker

    /// Create a local-only `Holding` from raw user input. Class is fixed to
    /// `self.assetClass`, status is `.estudo`, price is zero, `isCustom` is
    /// true. Returns false (and sets `errorMessage`) when the input is empty,
    /// the ticker already exists in this class, or the free-tier cap blocks
    /// the add.
    @discardableResult
    func addCustomTicker(
        symbol: String,
        modelContext: ModelContext
    ) -> Bool {
        let trimmed = symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !trimmed.isEmpty else { return false }

        if holdings.contains(where: { $0.ticker.uppercased() == trimmed }) {
            errorMessage = "\(trimmed) is already in your portfolio."
            return false
        }
        guard Holding.canAddMore(modelContext: modelContext) else {
            errorMessage = Holding.freeTierLimitMessage
            return false
        }
        errorMessage = nil

        let holding = Holding(
            ticker: trimmed,
            displayName: trimmed,
            currentPrice: 0,
            assetClass: assetClass,
            status: .estudo,
            isCustom: true
        )

        var descriptor = FetchDescriptor<Portfolio>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        if let portfolio = try? modelContext.fetch(descriptor).first {
            holding.portfolio = portfolio
        } else {
            let portfolio = Portfolio()
            modelContext.insert(portfolio)
            holding.portfolio = portfolio
        }
        modelContext.insert(holding)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
            return false
        }
        return true
    }

    // MARK: - Holding actions

    func deleteHolding(
        _ holding: Holding,
        modelContext: ModelContext,
        portfolio: Portfolio?,
        displayCurrency: Currency,
        rates: any ExchangeRates
    ) {
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
        // Persist the delete so subsequent re-reads (incl. the reactive
        // `portfolio.holdings` relationship) don't surface the stale row.
        try? modelContext.save()
        holdings.removeAll { $0.persistentModelID == holding.persistentModelID }
        loadData(
            portfolio: portfolio,
            modelContext: modelContext,
            displayCurrency: displayCurrency,
            rates: rates
        )
    }
}
