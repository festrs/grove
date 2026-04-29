import Foundation
import SwiftData
import GroveDomain

/// Backs `AddAssetDetailSheet`. Owns the form state, validation, and
/// persistence so the view stays layout-only per the project's MVVM rules.
@Observable
@MainActor
final class AddAssetViewModel {
    let searchResult: StockSearchResultDTO

    // Form state
    var detectedClass: AssetClassType
    var quantityText: String = ""
    var priceText: String = ""
    var date: Date = .now

    // Async / display state
    var isFetchingPrice: Bool = false
    var errorMessage: String?

    init(searchResult: StockSearchResultDTO) {
        self.searchResult = searchResult
        self.detectedClass = AssetClassType.detect(
            from: searchResult.symbol,
            apiType: searchResult.type
        ) ?? .acoesBR
    }

    // MARK: - Computed

    var quantity: Decimal? {
        Decimal(string: quantityText.replacingOccurrences(of: ",", with: "."))
    }

    var price: Decimal? {
        Decimal(string: priceText.replacingOccurrences(of: ",", with: "."))
    }

    var currency: Currency { detectedClass.defaultCurrency }

    var totalValue: Decimal {
        guard let q = quantity, let p = price else { return 0 }
        return q * p
    }

    var isValid: Bool {
        (quantity ?? 0) > 0 && (price ?? 0) > 0
    }

    // MARK: - Actions

    /// Pre-fill the price field from the search result, falling back to a
    /// fresh quote if needed. View calls this from `.task`.
    func fetchPrice(backendService: any BackendServiceProtocol) async {
        if let p = searchResult.priceDecimal, p > 0 {
            priceText = "\(p)"
            return
        }
        isFetchingPrice = true
        defer { isFetchingPrice = false }
        if let quote = try? await backendService.fetchStockQuote(symbol: searchResult.symbol) {
            priceText = "\(quote.price.decimalAmount)"
        }
    }

    /// Persist the new holding + opening contribution and kick off the
    /// bootstrap flow (track, batched price/DY pull, since-scoped dividend
    /// scrape). Returns true on success so the view can dismiss; false if
    /// validation or the free-tier cap blocks the add.
    @discardableResult
    func addAsset(
        modelContext: ModelContext,
        backendService: any BackendServiceProtocol
    ) -> Bool {
        guard let qty = quantity, let prc = price, qty > 0, prc > 0 else { return false }

        guard Holding.canAddMore(modelContext: modelContext) else {
            errorMessage = Holding.freeTierLimitMessage
            return false
        }
        errorMessage = nil

        let holding = Holding(
            ticker: searchResult.symbol,
            displayName: searchResult.name ?? searchResult.symbol,
            currentPrice: prc,
            assetClass: detectedClass,
            status: .aportar
        )
        holding.sector = searchResult.sector
        holding.logoURL = searchResult.logo

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

        let contribution = Contribution(
            date: date,
            amount: qty * prc,
            shares: qty,
            pricePerShare: prc
        )
        contribution.holding = holding
        modelContext.insert(contribution)
        holding.recalculateFromContributions()

        let symbol = searchResult.symbol
        let assetClass = detectedClass
        let bootstrap = TickerBootstrapService()
        Task { @MainActor in
            try? await backendService.trackSymbol(symbol: symbol, assetClass: assetClass.rawValue)
            await bootstrap.bootstrap(holdings: [holding], backendService: backendService)
            await bootstrap.refreshDividendsAfterTransaction(
                holding: holding,
                modelContext: modelContext,
                backendService: backendService
            )
        }

        return true
    }
}
