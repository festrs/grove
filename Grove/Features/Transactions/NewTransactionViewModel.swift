import Foundation
import SwiftData
import GroveDomain

/// Backs `NewTransactionView`. Owns the form state, validation, and the
/// buy/sell persistence flows so the view stays layout-only per the
/// project's MVVM rules.
@Observable
@MainActor
final class NewTransactionViewModel {
    let transactionType: NewTransactionView.TransactionType

    // Asset selection
    var selectedHolding: Holding?
    var isNewAsset: Bool = false
    var newTicker: String = ""
    var newDisplayName: String = ""
    var newAssetClass: AssetClassType = .acoesBR

    // Form fields
    var quantityText: String = ""
    var priceText: String = ""
    var date: Date = .now
    var notes: String = ""

    var errorMessage: String?

    init(transactionType: NewTransactionView.TransactionType) {
        self.transactionType = transactionType
    }

    /// Pre-fills `selectedHolding` once when the view appears, mirroring the
    /// previous inline behavior. Idempotent — repeated calls are no-ops if a
    /// selection is already in place.
    func applyPreselection(_ holding: Holding?) {
        guard let holding, selectedHolding == nil else { return }
        selectedHolding = holding
    }

    // MARK: - Computed

    var quantity: Decimal? {
        Decimal(string: quantityText.replacingOccurrences(of: ",", with: "."))
    }

    var price: Decimal? {
        Decimal(string: priceText.replacingOccurrences(of: ",", with: "."))
    }

    var totalValue: Decimal {
        guard let q = quantity, let p = price else { return 0 }
        return q * p
    }

    var currency: Currency {
        selectedHolding?.currency ?? newAssetClass.defaultCurrency
    }

    var isValid: Bool {
        let hasAsset = selectedHolding != nil || !newTicker.isEmpty
        let hasQty = (quantity ?? 0) > 0
        let hasPrice = (price ?? 0) > 0
        if transactionType == .sell, let holding = selectedHolding, let qty = quantity {
            return hasAsset && hasQty && hasPrice && qty <= holding.quantity
        }
        return hasAsset && hasQty && hasPrice
    }

    /// Apply a search-result tap: cache the picked symbol/name/class and
    /// fetch a fresh quote so the price field auto-fills.
    func selectSearchResult(
        _ result: StockSearchResultDTO,
        backendService: any BackendServiceProtocol
    ) {
        newTicker = result.symbol
        newDisplayName = result.name ?? result.symbol
        if let detected = AssetClassType.detect(from: result.symbol) {
            newAssetClass = detected
        }
        let symbol = result.symbol
        Task { @MainActor in
            if let quote = try? await backendService.fetchStockQuote(symbol: symbol) {
                priceText = "\(quote.price.decimalAmount)"
            }
        }
    }

    // MARK: - Submit

    /// Persist the buy or sell. Returns true on success so the view can
    /// dismiss; false if validation or the free-tier cap blocks it.
    @discardableResult
    func submit(
        modelContext: ModelContext,
        backendService: any BackendServiceProtocol
    ) -> Bool {
        guard isValid, let qty = quantity, let prc = price else {
            return false
        }

        switch transactionType {
        case .buy:
            return handleBuy(quantity: qty, price: prc, modelContext: modelContext, backendService: backendService)
        case .sell:
            return handleSell(quantity: qty, price: prc, modelContext: modelContext, backendService: backendService)
        }
    }

    private func handleBuy(
        quantity: Decimal,
        price: Decimal,
        modelContext: ModelContext,
        backendService: any BackendServiceProtocol
    ) -> Bool {
        let holding: Holding
        let isFreshAsset: Bool

        if let existing = selectedHolding {
            existing.currentPrice = price
            holding = existing
            isFreshAsset = false
        } else {
            guard Holding.canAddMore(modelContext: modelContext) else {
                errorMessage = Holding.freeTierLimitMessage
                return false
            }
            holding = Holding(
                ticker: newTicker,
                displayName: newDisplayName.isEmpty ? newTicker : newDisplayName,
                currentPrice: price,
                assetClass: newAssetClass,
                status: .aportar
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

            let sym = holding.ticker
            let cls = holding.assetClass.rawValue
            Task { try? await backendService.trackSymbol(symbol: sym, assetClass: cls) }
            isFreshAsset = true
        }

        let contribution = Contribution(date: date, amount: quantity * price, shares: quantity, pricePerShare: price)
        contribution.holding = holding
        modelContext.insert(contribution)

        // First buy on a study holding promotes it to .aportar.
        if holding.status == .estudo {
            holding.status = .aportar
        }

        holding.recalculateFromContributions()

        // Auto-fetch market data: bootstrap (price + DY) for brand-new
        // assets, and trigger a since-scoped on-demand dividend scrape for
        // any buy so the user's earned-payments view picks up the new
        // contribution window.
        let bootstrap = TickerBootstrapService()
        Task { @MainActor in
            if isFreshAsset {
                try? await backendService.trackSymbol(
                    symbol: holding.ticker,
                    assetClass: holding.assetClass.rawValue
                )
                await bootstrap.bootstrap(holdings: [holding], backendService: backendService)
            }
            await bootstrap.refreshDividendsAfterTransaction(
                holding: holding,
                modelContext: modelContext,
                backendService: backendService
            )
        }

        return true
    }

    private func handleSell(
        quantity: Decimal,
        price: Decimal,
        modelContext: ModelContext,
        backendService: any BackendServiceProtocol
    ) -> Bool {
        guard let holding = selectedHolding else { return false }

        let contribution = Contribution(date: date, amount: -(quantity * price), shares: -quantity, pricePerShare: price)
        contribution.holding = holding
        modelContext.insert(contribution)

        holding.recalculateFromContributions()

        if holding.quantity <= 0 {
            modelContext.delete(holding)
        }
        return true
    }
}
