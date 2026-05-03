import Foundation
import SwiftData
import GroveDomain

/// Backs `ImportPortfolioView`. Owns the post-parse confirmation step:
/// inserts the chosen positions, writes opening Contributions for ones with
/// quantity, registers the symbols with the backend, and kicks off the
/// per-add bootstrap + since-scoped dividend refresh so imports inherit
/// the same auto-fetch behavior as the single-add paths.
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

        var fresh: [Holding] = []
        var withTransaction: [Holding] = []

        for position in positions {
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

            if position.quantity > 0 {
                let pricePerShare = Decimal(position.currentPrice)
                let shares = Decimal(position.quantity)
                let contribution = Contribution(
                    date: .now,
                    amount: shares * pricePerShare,
                    shares: shares,
                    pricePerShare: pricePerShare
                )
                contribution.holding = holding
                modelContext.insert(contribution)
                holding.recalculateFromContributions()
                withTransaction.append(holding)
            }
        }

        try? modelContext.save()

        // Tracking + bootstrap + scoped dividend refresh. Best-effort: any
        // network failure leaves the local data intact and the user can hit
        // the manual refresh on the income drilldown to recover.
        let trackPairs = fresh.map { (symbol: $0.ticker, assetClass: $0.assetClass.rawValue) }
        let bootstrap = TickerBootstrapService()
        Task { @MainActor in
            try? await backendService.syncTrackedSymbols(pairs: trackPairs)
            await bootstrap.bootstrap(holdings: fresh, backendService: backendService)
            for h in withTransaction {
                await bootstrap.refreshDividendsAfterTransaction(
                    holding: h,
                    modelContext: modelContext,
                    backendService: backendService
                )
            }
        }
    }
}
