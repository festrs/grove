import Foundation
import SwiftData
import GroveDomain

/// Backs `AddAssetDetailSheet`. Owns the form state, validation, and
/// persistence so the view stays layout-only per the project's MVVM rules.
///
/// Two add modes are supported:
/// - `ownsPosition == false` (default): the holding is added as `.estudo`
///   with no opening contribution — the user is just tracking it.
/// - `ownsPosition == true`: requires positive quantity and price; creates
///   the holding as `.aportar` plus a bootstrap `Contribution` so the
///   portfolio reflects the existing position.
@Observable
@MainActor
final class AddAssetViewModel {
    let searchResult: StockSearchResultDTO
    let hasFixedClass: Bool
    let isCustom: Bool

    // Form state
    var detectedClass: AssetClassType
    var selectedStatus: HoldingStatus = .estudo
    var ownsPosition: Bool = false {
        didSet { syncStatusWithOwnership() }
    }
    var quantityText: String = ""
    var priceText: String = ""
    var date: Date = .now

    // Async / display state
    var isFetchingPrice: Bool = false
    var errorMessage: String?

    /// `assetClass` pins the holding's class — the new class-scoped Add flow
    /// always passes the screen's class so the user never picks one. Pass
    /// `nil` only for legacy entry points (e.g. onboarding) that still
    /// auto-detect from the search result. Set `isCustom = true` to persist
    /// a local-only Holding (no backend quote, no bootstrap).
    init(
        searchResult: StockSearchResultDTO,
        assetClass: AssetClassType? = nil,
        isCustom: Bool = false
    ) {
        self.searchResult = searchResult
        self.isCustom = isCustom
        if let assetClass {
            self.detectedClass = assetClass
            self.hasFixedClass = true
        } else if isCustom {
            self.detectedClass = .acoesBR
            self.hasFixedClass = false
        } else {
            self.detectedClass = AssetClassType.detect(
                from: searchResult.symbol,
                apiType: searchResult.type
            ) ?? .acoesBR
            self.hasFixedClass = false
        }
    }

    /// Build a VM for a manually-typed ticker. Synthesizes a minimal DTO so
    /// the rest of the form (header card, position section) keeps working
    /// without branching on `isCustom` everywhere.
    static func custom(symbol: String) -> AddAssetViewModel {
        let trimmed = symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let dto = StockSearchResultDTO(id: trimmed, symbol: trimmed, name: trimmed)
        return AddAssetViewModel(searchResult: dto, assetClass: nil, isCustom: true)
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
        if !ownsPosition { return true }
        return (quantity ?? 0) > 0 && (price ?? 0) > 0
    }

    /// Keep the explicit status picker in sync with the position toggle:
    /// flipping "I already own this" on bumps `.estudo` → `.aportar`; off
    /// drops `.aportar` → `.estudo`. Other status choices are left alone so
    /// the user can pick `.quarentena`/`.vender` deliberately.
    private func syncStatusWithOwnership() {
        if ownsPosition, selectedStatus == .estudo {
            selectedStatus = .aportar
        } else if !ownsPosition, selectedStatus == .aportar {
            selectedStatus = .estudo
        }
    }

    // MARK: - Actions

    /// Pre-fill the price field from the search result, falling back to a
    /// fresh quote if needed. View calls this from `.task`. Custom tickers
    /// have no backend record, so we don't query.
    func fetchPrice(backendService: any BackendServiceProtocol) async {
        if isCustom { return }
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

    /// Persist the new holding (and an opening contribution when
    /// `ownsPosition == true`) and kick off the bootstrap flow. Returns true
    /// on success so the view can dismiss; false if validation or the
    /// free-tier cap blocks the add.
    @discardableResult
    func addAsset(
        modelContext: ModelContext,
        backendService: any BackendServiceProtocol
    ) -> Bool {
        guard isValid else { return false }
        guard Holding.canAddMore(modelContext: modelContext) else {
            errorMessage = Holding.freeTierLimitMessage
            return false
        }
        errorMessage = nil

        // currentPrice on the Holding always reflects the live quote when
        // available — even in track-only mode — so the dashboard projection
        // works without waiting for the next sync.
        let livePrice = searchResult.priceDecimal ?? price ?? 0

        let holding = Holding(
            ticker: searchResult.symbol,
            displayName: searchResult.name ?? searchResult.symbol,
            currentPrice: livePrice,
            assetClass: detectedClass,
            status: selectedStatus,
            isCustom: isCustom
        )
        if !isCustom {
            holding.sector = searchResult.sector
            holding.logoURL = searchResult.logo
        }

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

        if ownsPosition, let qty = quantity, let prc = price, qty > 0, prc > 0 {
            let contribution = Contribution(
                date: date,
                amount: qty * prc,
                shares: qty,
                pricePerShare: prc
            )
            contribution.holding = holding
            modelContext.insert(contribution)
            holding.recalculateFromContributions()
        }

        // Persist immediately so the Holding gets a permanent
        // PersistentIdentifier before the sheet dismisses. Without this the
        // ID is "temporary" and any `@Query` refresh invalidates it,
        // crashing navigation into the holding detail.
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
            return false
        }

        // Custom tickers are local-only — the backend has no record so
        // tracking + bootstrap would just produce best-effort failures.
        if !isCustom {
            let symbol = searchResult.symbol
            let assetClass = detectedClass
            let bootstrap = TickerBootstrapService()
            let owns = ownsPosition
            Task { @MainActor in
                try? await backendService.trackSymbol(symbol: symbol, assetClass: assetClass.rawValue)
                await bootstrap.bootstrap(holdings: [holding], backendService: backendService)
                if owns {
                    await bootstrap.refreshDividendsAfterTransaction(
                        holding: holding,
                        modelContext: modelContext,
                        backendService: backendService
                    )
                }
            }
        }

        return true
    }

    /// Snapshot the form as a `PendingHolding` for the onboarding flow,
    /// which buffers drafts in memory until the user finishes the wizard.
    func toPendingHolding() -> PendingHolding {
        PendingHolding(
            ticker: searchResult.symbol.uppercased(),
            displayName: searchResult.name ?? searchResult.symbol,
            quantity: ownsPosition ? (quantity ?? 0) : 0,
            assetClass: detectedClass,
            status: selectedStatus,
            currentPrice: searchResult.priceDecimal ?? price ?? 0,
            dividendYield: 0,
            apiType: searchResult.type,
            averagePrice: ownsPosition ? price : nil,
            purchaseDate: ownsPosition ? date : nil
        )
    }
}
