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

    func loadHolding(id: PersistentIdentifier, modelContext: ModelContext) {
        holding = modelContext.model(for: id) as? Holding
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

    /// Remove the holding from the portfolio. If it still has shares, write
    /// a zeroing-out Contribution first so historical reports don't lose
    /// the position outright. View is responsible for dismissing.
    func removeHolding(modelContext: ModelContext) {
        guard let holding else { return }
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
        try? modelContext.save()
        self.holding = nil
    }
}
