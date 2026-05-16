import Foundation
import SwiftData
import GroveDomain

/// Backs `HoldingDetailView`. Owns the live holding reference, the
/// fundamentals fetch state, and the destructive remove flow so the view
/// stays layout-only.
@Observable
@MainActor
final class HoldingDetailViewModel {
    var holding: Holding?
    var isLoading = false
    var error: String?

    var fundamentals: FundamentalsDTO?
    var isFundamentalsLoading = false

    // UI sheet/alert state — lives on the VM so the view stays layout-only
    // and the orchestration (e.g. flipping `showRemoveAlert` off after a
    // confirmation) is testable.
    var showRemoveAlert = false
    var showingBuy = false
    var showingSell = false

    /// Set when the user swipes Delete on a Transaction row. Drives the
    /// confirmation dialog. Nil means no pending deletion.
    var pendingDeletion: Transaction?

    /// Flipped synchronously the moment the user confirms removal. Drives
    /// `resolvedHolding(...)` to nil so the view stops touching the model
    /// before the delete commits — SwiftData re-materializes a deleted
    /// persistent ID as `_InvalidFutureBackingData`, and reading any
    /// persisted property on that placeholder traps. There's no working
    /// `isDeleted` flag in SwiftData to guard on instead.
    private(set) var didRemove = false

    func loadHolding(id: PersistentIdentifier, modelContext: ModelContext) {
        holding = modelContext.model(for: id) as? Holding
    }

    /// `.task` entry point: load the holding, then kick off a price +
    /// fundamentals refresh — but only for backend-tracked holdings.
    /// Custom holdings have no quote/fundamentals source, so refreshing
    /// would be a no-op at best and stomp manual values at worst.
    func onAppear(
        id: PersistentIdentifier,
        modelContext: ModelContext,
        backendService: any BackendServiceProtocol
    ) async {
        loadHolding(id: id, modelContext: modelContext)
        guard let holding, holding.hasBackendEnrichment else { return }
        await refreshAll(backendService: backendService)
    }

    /// `.refreshable` entry point: same gate as `onAppear` but without
    /// the load step (pull-to-refresh runs while the view already has a
    /// loaded holding).
    func refreshIfNeeded(backendService: any BackendServiceProtocol) async {
        guard let holding, holding.hasBackendEnrichment else { return }
        await refreshAll(backendService: backendService)
    }

    /// Source of truth the view should read for "what holding to render."
    /// Falls back to a context lookup so the first frame after navigation
    /// has data without waiting on `.task`, but short-circuits once
    /// removal has begun so the body never reads a soon-to-be-invalid
    /// SwiftData object.
    func resolvedHolding(id: PersistentIdentifier, modelContext: ModelContext) -> Holding? {
        guard !didRemove else { return nil }
        return holding ?? (modelContext.model(for: id) as? Holding)
    }

    /// Refresh price + fundamentals concurrently. Each branch swallows its
    /// own error so a stale fundamentals payload doesn't take down the
    /// price update (and vice-versa). The shared `error` field stays for
    /// price failures since that's the user-visible one.
    func refreshAll(backendService: any BackendServiceProtocol) async {
        guard let holding else { return }
        let symbol = holding.ticker
        let needsFundamentals = holding.assetClass.hasFundamentals

        async let priceTask: Void = updatePrice(symbol: symbol, backendService: backendService)
        async let fundamentalsTask: Void = updateFundamentals(symbol: symbol, enabled: needsFundamentals, backendService: backendService)

        _ = await (priceTask, fundamentalsTask)
    }

    /// Single-shot price refresh — kept on the public API since some entry
    /// points only need the quote (e.g. quick refresh button) without
    /// touching fundamentals.
    func updatePrice(backendService: any BackendServiceProtocol) async {
        guard let holding else { return }
        await updatePrice(symbol: holding.ticker, backendService: backendService)
    }

    private func updatePrice(symbol: String, backendService: any BackendServiceProtocol) async {
        guard let holding else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let quote = try await backendService.fetchStockQuote(symbol: symbol)
            holding.currentPrice = quote.price.decimalAmount
            holding.lastPriceUpdate = .now
            if let mc = quote.marketCap {
                holding.marketCap = mc.amount
            }
            // Skip nil/zero so a provider miss doesn't stomp a previously
            // populated yield (mirrors SyncService.syncPrices).
            if let dy = quote.dividendYieldDecimal, dy > 0 {
                holding.dividendYield = dy
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func updateFundamentals(symbol: String, enabled: Bool, backendService: any BackendServiceProtocol) async {
        guard enabled else {
            fundamentals = nil
            return
        }
        isFundamentalsLoading = true
        defer { isFundamentalsLoading = false }
        if let result = try? await backendService.fetchFundamentals(symbol: symbol) {
            fundamentals = result
        }
        // On error, keep the previously-loaded fundamentals — better than
        // wiping the user's view because of a transient hiccup.
    }

    // MARK: - Transaction deletion (history prune)

    /// Stash the row the user just swiped. The view binds a confirmation
    /// dialog to `pendingDeletion`; cancel/confirm clear it.
    func requestDeleteTransaction(_ t: Transaction) {
        pendingDeletion = t
    }

    func cancelDeleteTransaction() {
        pendingDeletion = nil
    }

    /// Delete the pending Transaction from the context. Intentionally does
    /// NOT call `recalculateFromTransactions()` — per product decision,
    /// deletion is a log prune and must not mutate the holding's cached
    /// quantity/averagePrice/status. The ledger and the cached numbers
    /// reconcile on the next buy/sell. See CLAUDE.md.
    func confirmDeleteTransaction(modelContext: ModelContext) {
        guard let target = pendingDeletion else { return }
        pendingDeletion = nil
        modelContext.delete(target)
        try? modelContext.save()
    }

    /// Remove the holding from the portfolio. If it still has shares, write
    /// a zeroing-out Transaction first so historical reports don't lose
    /// the position outright. Flips `didRemove` synchronously *before*
    /// touching the context so any concurrent body render reads through
    /// `resolvedHolding(...)` and gets nil instead of a doomed SwiftData
    /// object. View is responsible for dismissing.
    func removeHolding(modelContext: ModelContext) {
        guard let holding else { return }
        didRemove = true
        if holding.hasPosition {
            let transaction = Transaction(
                date: .now,
                amount: -(holding.quantity * holding.currentPrice),
                shares: -holding.quantity,
                pricePerShare: holding.currentPrice
            )
            transaction.holding = holding
            modelContext.insert(transaction)
        }
        modelContext.delete(holding)
        try? modelContext.save()
        self.holding = nil
    }
}
