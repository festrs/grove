import Foundation
import SwiftData

struct RebalancingSuggestion: Identifiable {
    var id: String { ticker }
    let ticker: String
    let displayName: String
    let sharesToBuy: Int
    let amount: Decimal
    let currentPercent: Decimal
    let targetPercent: Decimal
    let newPercent: Decimal

    var displayTicker: String {
        ticker.replacingOccurrences(of: ".SA", with: "")
    }
}

struct RebalancingEngine {

    // MARK: - Public API

    /// Fetches portfolio data and returns rebalancing suggestions, limited to the user's recommendation count.
    /// Single entry point used by both Dashboard and Aportar tab.
    static func suggestions(
        modelContext: ModelContext,
        investmentAmount: Decimal,
        exchangeRate: Decimal = 5.12
    ) throws -> [RebalancingSuggestion] {
        let repo = PortfolioRepository(modelContext: modelContext)
        let holdings = try HoldingRepository(modelContext: modelContext).fetchAll()
        let settings = try repo.fetchSettings()

        let globalAllocations = settings.classAllocations

        if globalAllocations.isEmpty {
            return calculate(
                holdings: holdings,
                investmentAmount: investmentAmount,
                maxRecommendations: settings.recommendationCount,
                exchangeRate: exchangeRate
            )
        } else {
            return calculate(
                holdings: holdings,
                investmentAmount: investmentAmount,
                classAllocations: globalAllocations,
                maxRecommendations: settings.recommendationCount,
                exchangeRate: exchangeRate
            )
        }
    }

    /// Two-tier Bastter rebalancing with explicit class allocations.
    static func calculate(
        holdings: [Holding],
        investmentAmount: Decimal,
        classAllocations: [AssetClassType: Double],
        maxRecommendations: Int = .max,
        exchangeRate: Decimal = 5.12
    ) -> [RebalancingSuggestion] {
        guard investmentAmount > 0 else { return [] }

        let context = buildContext(holdings: holdings, investmentAmount: investmentAmount, exchangeRate: exchangeRate)
        print("[Rebalance][engine] holdings=\(holdings.count) eligible=\(context.eligible.count) totalValue=\(context.totalValue)")
        for h in context.eligible {
            print("    eligible: \(h.ticker) class=\(h.assetClassRaw) price=\(h.currentPrice) targetPct=\(h.targetPercent)")
        }
        // totalValue == 0 is fine — happens when every .aportar ticker has quantity 0
        // (first investment, or onboarding with all in study/aportar). Class gaps fall
        // back to full target weight, and we still need to score the eligible holdings.
        guard !context.eligible.isEmpty else {
            print("[Rebalance][engine] no eligible — returning empty")
            return []
        }

        let scored = scoreHoldings(
            eligible: context.eligible,
            classAllocations: classAllocations,
            totalValue: context.totalValue,
            valueByClass: context.valueByClass,
            exchangeRate: exchangeRate
        )
        guard !scored.isEmpty else { return [] }

        return allocateBudget(
            scored: scored,
            investmentAmount: investmentAmount,
            maxRecommendations: maxRecommendations,
            totalValue: context.totalValue,
            newTotalValue: context.newTotalValue,
            exchangeRate: exchangeRate
        )
    }

    /// Simplified overload — derives equal class allocations from holdings.
    static func calculate(
        holdings: [Holding],
        investmentAmount: Decimal,
        maxRecommendations: Int = .max,
        exchangeRate: Decimal = 5.12
    ) -> [RebalancingSuggestion] {
        let activeClasses = Set(holdings.map { $0.assetClass })
        guard !activeClasses.isEmpty else { return [] }
        let perClass = 100.0 / Double(activeClasses.count)
        let classAlloc = Dictionary(uniqueKeysWithValues: activeClasses.map { ($0, perClass) })
        return calculate(
            holdings: holdings,
            investmentAmount: investmentAmount,
            classAllocations: classAlloc,
            maxRecommendations: maxRecommendations,
            exchangeRate: exchangeRate
        )
    }

    // MARK: - Context

    private struct PortfolioContext {
        let totalValue: Decimal
        let newTotalValue: Decimal
        let valueByClass: [AssetClassType: Decimal]
        let eligible: [Holding]
    }

    private static func buildContext(
        holdings: [Holding],
        investmentAmount: Decimal,
        exchangeRate: Decimal
    ) -> PortfolioContext {
        var totalValue: Decimal = 0
        var valueByClass: [AssetClassType: Decimal] = [:]

        for h in holdings {
            // Vender holdings are excluded from allocation math entirely
            guard h.status != .vender else { continue }
            let brlValue = h.currency == .usd ? h.currentValue * exchangeRate : h.currentValue
            totalValue += brlValue
            valueByClass[h.assetClass, default: 0] += brlValue
        }

        let eligible = holdings.filter { $0.status == .aportar && $0.currentPrice > 0 }

        return PortfolioContext(
            totalValue: totalValue,
            newTotalValue: totalValue + investmentAmount,
            valueByClass: valueByClass,
            eligible: eligible
        )
    }

    // MARK: - Scoring

    private struct ScoredHolding {
        let holding: Holding
        let classGap: Decimal
        let weight: Decimal
        let brlPrice: Decimal
        let classTarget: Decimal
        let budgetShare: Decimal  // proportion of total budget this holding should get
    }

    private static func scoreHoldings(
        eligible: [Holding],
        classAllocations: [AssetClassType: Double],
        totalValue: Decimal,
        valueByClass: [AssetClassType: Decimal],
        exchangeRate: Decimal
    ) -> [ScoredHolding] {
        guard !eligible.isEmpty else { return [] }

        // Class gaps
        var classGap: [AssetClassType: Decimal] = [:]
        for (ct, target) in classAllocations {
            let currentPct = totalValue > 0 ? ((valueByClass[ct] ?? 0) / totalValue) * 100 : 0
            classGap[ct] = Decimal(target) - currentPct
        }

        // Holding weights per class
        var weightByClass: [AssetClassType: Decimal] = [:]
        for h in eligible {
            weightByClass[h.assetClass, default: 0] += h.targetPercent
        }

        // Score each holding: class gap * holding proportion within class
        var scored: [ScoredHolding] = eligible.compactMap { h in
            let gap = classGap[h.assetClass] ?? 0
            let brlPrice = h.currency == .usd ? h.currentPrice * exchangeRate : h.currentPrice
            guard brlPrice > 0 else { return nil }

            let classTotal = weightByClass[h.assetClass] ?? 1
            let holdingShare = classTotal > 0 ? h.targetPercent / classTotal : 1

            return ScoredHolding(
                holding: h,
                classGap: gap,
                weight: h.targetPercent,
                brlPrice: brlPrice,
                classTarget: Decimal(classAllocations[h.assetClass] ?? 0),
                budgetShare: holdingShare
            )
        }

        // Sort: most underweight class first, then highest weight within class
        scored.sort { a, b in
            if a.classGap != b.classGap { return a.classGap > b.classGap }
            return a.weight > b.weight
        }

        return scored
    }

    // MARK: - Budget Allocation

    private static func allocateBudget(
        scored: [ScoredHolding],
        investmentAmount: Decimal,
        maxRecommendations: Int,
        totalValue: Decimal,
        newTotalValue: Decimal,
        exchangeRate: Decimal
    ) -> [RebalancingSuggestion] {
        // Take top N scored holdings, split budget equally
        let limit = min(maxRecommendations, scored.count)
        guard limit > 0 else { return [] }
        let topN = Array(scored.prefix(limit))
        let perHolding = investmentAmount / Decimal(topN.count)

        var suggestions: [RebalancingSuggestion] = []
        var remaining = investmentAmount

        for sh in topN {
            let budget = min(perHolding, remaining)
            let shares = Int(NSDecimalNumber(decimal: budget / sh.brlPrice).doubleValue)
            guard shares > 0 else { continue }

            let actualAmount = Decimal(shares) * sh.brlPrice
            guard actualAmount <= remaining else { continue }

            let brlValue = sh.holding.currency == .usd
                ? sh.holding.currentValue * exchangeRate
                : sh.holding.currentValue

            suggestions.append(RebalancingSuggestion(
                ticker: sh.holding.ticker,
                displayName: sh.holding.displayName,
                sharesToBuy: shares,
                amount: actualAmount,
                currentPercent: percent(of: brlValue, total: totalValue),
                targetPercent: sh.classTarget,
                newPercent: percent(of: brlValue + actualAmount, total: newTotalValue)
            ))
            remaining -= actualAmount
        }

        // Redistribute remainder to highest-priority affordable holding
        if remaining > 0 {
            for sh in scored {
                guard remaining >= sh.brlPrice else { continue }
                let extraShares = Int(NSDecimalNumber(decimal: remaining / sh.brlPrice).doubleValue)
                guard extraShares > 0 else { continue }

                let extraAmount = Decimal(extraShares) * sh.brlPrice
                if let idx = suggestions.firstIndex(where: { $0.ticker == sh.holding.ticker }) {
                    let old = suggestions[idx]
                    let brlValue = sh.holding.currency == .usd
                        ? sh.holding.currentValue * exchangeRate
                        : sh.holding.currentValue
                    suggestions[idx] = RebalancingSuggestion(
                        ticker: old.ticker,
                        displayName: old.displayName,
                        sharesToBuy: old.sharesToBuy + extraShares,
                        amount: old.amount + extraAmount,
                        currentPercent: old.currentPercent,
                        targetPercent: old.targetPercent,
                        newPercent: percent(of: brlValue + old.amount + extraAmount, total: newTotalValue)
                    )
                } else {
                    let brlValue = sh.holding.currency == .usd
                        ? sh.holding.currentValue * exchangeRate
                        : sh.holding.currentValue
                    suggestions.append(RebalancingSuggestion(
                        ticker: sh.holding.ticker,
                        displayName: sh.holding.displayName,
                        sharesToBuy: extraShares,
                        amount: extraAmount,
                        currentPercent: percent(of: brlValue, total: totalValue),
                        targetPercent: sh.classTarget,
                        newPercent: percent(of: brlValue + extraAmount, total: newTotalValue)
                    ))
                }
                remaining -= extraAmount
                break
            }
        }

        return suggestions.sorted { $0.amount > $1.amount }
    }

    private static func percent(of value: Decimal, total: Decimal) -> Decimal {
        guard total > 0 else { return 0 }
        return (value / total) * 100
    }
}
