import Foundation
import SwiftData
import GroveDomain

/// Backs `ImportPortfolioView`. Owns the post-parse confirmation step:
/// inserts the chosen positions, writes opening Contributions for ones with
/// quantity, registers the symbols with the backend, and kicks off the
/// price/yield bootstrap. Skips per-holding dividend backfill on purpose —
/// imported contributions are dated `.now`, so a since-scoped scrape would
/// be a no-op, and per-symbol fan-out blows through the backend's 4/min
/// rate limit on `/refresh`. Mirrors `OnboardingViewModel`'s reasoning;
/// users can backfill via the per-class manual refresh on the income
/// drilldown.
@Observable
@MainActor
final class ImportPortfolioViewModel {

    func confirmImport(
        positions: [ImportedPosition],
        portfolio: Portfolio,
        modelContext: ModelContext,
        backendService: any BackendServiceProtocol
    ) {
        guard !positions.isEmpty else { return }

        // Newly created Holdings — get full tracking + bootstrap. Existing
        // ones we merge into are already tracked.
        var fresh: [Holding] = []

        for position in positions {
            let canonical = position.ticker.normalizedTicker
            let target: Holding
            if let existing = portfolio.holdings.first(where: { $0.ticker == canonical }) {
                target = existing
            } else {
                let assetClass = position.assetClassType
                let holding = Holding(
                    ticker: position.ticker,
                    displayName: position.displayName,
                    currentPrice: Decimal(position.currentPrice),
                    assetClass: assetClass,
                    status: position.quantity > 0 ? .aportar : .estudo
                )
                holding.portfolio = portfolio
                modelContext.insert(holding)
                fresh.append(holding)
                target = holding
            }

            if position.quantity > 0 {
                let pricePerShare = Decimal(position.currentPrice)
                let shares = Decimal(position.quantity)
                let contribution = Contribution(
                    date: .now,
                    amount: shares * pricePerShare,
                    shares: shares,
                    pricePerShare: pricePerShare
                )
                contribution.holding = target
                modelContext.insert(contribution)
                target.recalculateFromContributions()
                if target.status == .estudo {
                    target.status = .aportar
                }
            }
        }

        try? modelContext.save()

        // Tracking + price/yield bootstrap. Best-effort: any network failure
        // leaves the local data intact. Dividend backfill is left to the
        // per-class manual refresh button (see header comment).
        let trackPairs = fresh.map { (symbol: $0.ticker, assetClass: $0.assetClass.rawValue) }
        let bootstrap = TickerBootstrapService()
        Task { @MainActor in
            if !trackPairs.isEmpty {
                try? await backendService.syncTrackedSymbols(pairs: trackPairs)
            }
            await bootstrap.bootstrap(holdings: fresh, backendService: backendService)
        }
    }
}
