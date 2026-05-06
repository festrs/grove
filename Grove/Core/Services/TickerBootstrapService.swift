import Foundation
import SwiftData
import GroveDomain

/// Bridges "user just added a ticker" → "backend has fresh data for it".
///
/// The split between bootstrap and refresh-after-transaction matches the
/// agreed cost discipline:
///
/// - **`bootstrap(holdings:)`** runs on every add path (study, buy, import).
///   Uses the cheap, already-batched `fetchBatchQuotes` — the same payload
///   carries `currentPrice` and `dividendYield`, so the ticker shows real
///   numbers immediately. No upstream provider scrape — it just reads what
///   the backend already has.
///
/// - **`refreshDividendsAfterTransaction(holding:)`** triggers the on-demand
///   provider scrape via `BackendServiceProtocol.refreshDividends`, scoped to
///   the first-Contribution date so we don't pull payments from before the
///   user owned the asset. Only call this once a Contribution has landed on
///   the holding — study tickers don't need historical dividends and
///   shouldn't burn provider quota.
///
/// Best-effort by design: any backend error is swallowed so the user's
/// add-flow never fails because of a market-data hiccup. The manual refresh
/// button on `AssetClassDividendsView` is the recovery path.
@MainActor
struct TickerBootstrapService {

    /// Pull a fresh quote for the given holdings and write `currentPrice` +
    /// `dividendYield` + `lastPriceUpdate`. Cheap — uses only the aggregated
    /// mobile quotes endpoint, never the provider scrape.
    func bootstrap(
        holdings: [Holding],
        backendService: any BackendServiceProtocol
    ) async {
        let holdings = holdings.filter { !$0.isCustom }
        guard !holdings.isEmpty else { return }
        let symbols = holdings.map(\.ticker)

        let quotes = (try? await backendService.fetchBatchQuotes(symbols: symbols)) ?? []

        for holding in holdings {
            guard let quote = quotes.first(where: { $0.symbol == holding.ticker }) else { continue }
            if let price = quote.price {
                holding.currentPrice = price.decimalAmount
                holding.lastPriceUpdate = .now
            }
            // Backend returns dividend_yield already in percent. Skip nil/zero
            // so a missing value doesn't stomp an existing yield.
            if let dy = quote.dividendYieldDecimal, dy > 0 {
                holding.dividendYield = dy
            }
        }
    }

    /// Trigger an on-demand dividend scrape for the holding's ticker, scoped
    /// to its first-Contribution date so the store doesn't accumulate
    /// pre-purchase payments. No-op when the holding has no contributions
    /// yet — callers should invoke this *after* writing the new
    /// `Contribution` and calling `holding.recalculateFromContributions()`.
    func refreshDividendsAfterTransaction(
        holding: Holding,
        modelContext: ModelContext,
        backendService: any BackendServiceProtocol
    ) async {
        guard !holding.isCustom else { return }
        guard let firstDate = holding.contributions.map(\.date).min() else { return }
        let symbol = holding.ticker
        let assetClassRaw = holding.assetClass.rawValue

        do {
            _ = try await backendService.refreshDividends(
                symbols: [symbol],
                assetClass: assetClassRaw,
                since: firstDate
            )
            // Pull the freshly-scraped records into the local store. Reuse
            // SyncService.syncDividends so the dedup + write logic stays in
            // one place.
            try await SyncService().syncDividends(
                modelContext: modelContext,
                backendService: backendService
            )
            try? modelContext.save()
        } catch {
            // Best-effort. The manual refresh button covers the recovery path.
        }
    }
}
