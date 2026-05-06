import Foundation
import SwiftData
import GroveDomain
import GroveRepositories

/// Backs `AssetClassHoldingsView`. Owns the class-scoped holdings list and
/// the per-row buy/sell/remove sheet state. Add and search live in the
/// global `AddTickerSheet` flow now — this VM no longer holds search state.
@Observable
@MainActor
final class AssetClassHoldingsViewModel {
    let assetClass: AssetClassType

    var holdings: [Holding] = []
    var classTotalValue: Money = .zero(in: .brl)
    var classCurrentPercent: Decimal = 0
    var classTargetPercent: Decimal = 0

    var holdingToBuy: Holding?
    var holdingToSell: Holding?
    var holdingToRemove: Holding?

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
