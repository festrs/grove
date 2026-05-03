import Foundation
import SwiftData
import GroveDomain

/// Bridges "user just added a ticker" → "backend has fresh data for it".
///
/// The split between bootstrap and refresh-after-transaction matches the
/// agreed cost discipline:
///
/// - **`bootstrap(holdings:)`** runs on every add path (study, buy, import).
///   Uses the cheap, already-batched `fetchBatchQuotes` + `fetchDividendSummary`
///   so the ticker shows a real `currentPrice` and a non-zero `dividendYield`
///   immediately. No upstream provider scrape — it just reads what the
///   backend already has.
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

    /// Pull a fresh quote and DY summary for the given holdings and write
    /// `currentPrice` + `dividendYield` + `lastPriceUpdate`. Cheap — uses
    /// only the aggregated mobile endpoints, never the provider scrape.
    func bootstrap(
        holdings: [Holding],
        backendService: any BackendServiceProtocol
    ) async {
        let holdings = holdings.filter { !$0.isCustom }
        guard !holdings.isEmpty else { return }
        let symbols = holdings.map(\.ticker)

        async let quotesTask = (try? await backendService.fetchBatchQuotes(symbols: symbols)) ?? []
        async let summaryTask = (try? await backendService.fetchDividendSummary(symbols: symbols)) ?? [:]

        let quotes = await quotesTask
        let summary = await summaryTask

        for holding in holdings {
            if let quote = quotes.first(where: { $0.symbol == holding.ticker }),
               let price = quote.price {
                holding.currentPrice = price.decimalAmount
                holding.lastPriceUpdate = .now
            }
            if let dps = summary[holding.ticker]?.decimalValue,
               holding.currentPrice > 0,
               dps > 0 {
                holding.dividendYield = (dps / holding.currentPrice) * 100
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
