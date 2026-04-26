import Foundation
import SwiftData

struct RebalancingSuggestion: Identifiable {
    var id: String { ticker }
    let ticker: String
    let displayName: String
    let sharesToBuy: Int
    let amount: Money
    let currentPercent: Decimal
    let targetPercent: Decimal
    let newPercent: Decimal

    var displayTicker: String {
        ticker.replacingOccurrences(of: ".SA", with: "")
    }
}

struct RebalancingEngine {

    // MARK: - Public API

    static func suggestions(
        modelContext: ModelContext,
        investmentAmount: Money,
        rates: any ExchangeRates
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
                rates: rates
            )
        } else {
            return calculate(
                holdings: holdings,
                investmentAmount: investmentAmount,
                classAllocations: globalAllocations,
                maxRecommendations: settings.recommendationCount,
                rates: rates
            )
        }
    }

    static func calculate(
        holdings: [Holding],
        investmentAmount: Money,
        classAllocations: [AssetClassType: Double],
        maxRecommendations: Int = .max,
        rates: any ExchangeRates
    ) -> [RebalancingSuggestion] {
        guard investmentAmount.amount > 0 else { return [] }

        let context = buildContext(holdings: holdings, investmentAmount: investmentAmount, rates: rates)
        guard !context.eligible.isEmpty else { return [] }

        let scored = scoreHoldings(
            eligible: context.eligible,
            classAllocations: classAllocations,
            totalValue: context.totalValue,
            valueByClass: context.valueByClass,
            rates: rates
        )
        guard !scored.isEmpty else { return [] }

        return allocateBudget(
            scored: scored,
            investmentAmount: investmentAmount,
            maxRecommendations: maxRecommendations,
            totalValue: context.totalValue,
            newTotalValue: context.newTotalValue,
            rates: rates
        )
    }

    /// Simplified overload — derives equal class allocations from holdings.
    static func calculate(
        holdings: [Holding],
        investmentAmount: Money,
        maxRecommendations: Int = .max,
        rates: any ExchangeRates
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
            rates: rates
        )
    }

    // MARK: - Context

    private struct PortfolioContext {
        let totalValue: Money
        let newTotalValue: Money
        let valueByClass: [AssetClassType: Money]
        let eligible: [Holding]
    }

    private static func buildContext(
        holdings: [Holding],
        investmentAmount: Money,
        rates: any ExchangeRates
    ) -> PortfolioContext {
        var valueByClass: [AssetClassType: Money] = [:]
        var totals: [Money] = []

        for h in holdings {
            guard h.status != .vender else { continue }
            let value = h.currentValueMoney
            totals.append(value)
            valueByClass[h.assetClass] = (valueByClass[h.assetClass] ?? .zero(in: h.currency)) + value
        }

        let totalValue = totals.sum(in: investmentAmount.currency, using: rates)
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
        let pricePerShareInBudgetCurrency: Decimal
        let classTarget: Decimal
        let budgetShare: Decimal
    }

    private static func scoreHoldings(
        eligible: [Holding],
        classAllocations: [AssetClassType: Double],
        totalValue: Money,
        valueByClass: [AssetClassType: Money],
        rates: any ExchangeRates
    ) -> [ScoredHolding] {
        guard !eligible.isEmpty else { return [] }

        let budgetCurrency = totalValue.currency

        var classGap: [AssetClassType: Decimal] = [:]
        for (ct, target) in classAllocations {
            let nativeValue = valueByClass[ct] ?? .zero(in: budgetCurrency)
            let displayValue = nativeValue.converted(to: budgetCurrency, using: rates)
            let currentPct: Decimal = totalValue.amount > 0 ? (displayValue.amount / totalValue.amount) * 100 : 0
            classGap[ct] = Decimal(target) - currentPct
        }

        var weightByClass: [AssetClassType: Decimal] = [:]
        for h in eligible {
            weightByClass[h.assetClass, default: 0] += h.targetPercent
        }

        var scored: [ScoredHolding] = eligible.compactMap { h in
            let gap = classGap[h.assetClass] ?? 0
            let priceInBudget = h.priceMoney.converted(to: budgetCurrency, using: rates).amount
            guard priceInBudget > 0 else { return nil }

            let classTotal = weightByClass[h.assetClass] ?? 1
            let holdingShare = classTotal > 0 ? h.targetPercent / classTotal : 1

            return ScoredHolding(
                holding: h,
                classGap: gap,
                weight: h.targetPercent,
                pricePerShareInBudgetCurrency: priceInBudget,
                classTarget: Decimal(classAllocations[h.assetClass] ?? 0),
                budgetShare: holdingShare
            )
        }

        scored.sort { a, b in
            if a.classGap != b.classGap { return a.classGap > b.classGap }
            return a.weight > b.weight
        }

        return scored
    }

    // MARK: - Budget Allocation

    private static func allocateBudget(
        scored: [ScoredHolding],
        investmentAmount: Money,
        maxRecommendations: Int,
        totalValue: Money,
        newTotalValue: Money,
        rates: any ExchangeRates
    ) -> [RebalancingSuggestion] {
        let limit = min(maxRecommendations, scored.count)
        guard limit > 0 else { return [] }
        let topN = Array(scored.prefix(limit))
        let perHolding = investmentAmount.amount / Decimal(topN.count)

        var suggestions: [RebalancingSuggestion] = []
        var remaining = investmentAmount.amount

        for sh in topN {
            let budget = min(perHolding, remaining)
            let shares = Int(NSDecimalNumber(decimal: budget / sh.pricePerShareInBudgetCurrency).doubleValue)
            guard shares > 0 else { continue }

            let actualAmountBudget = Decimal(shares) * sh.pricePerShareInBudgetCurrency
            guard actualAmountBudget <= remaining else { continue }

            // Native amount user actually pays (in holding's currency)
            let nativeAmount = Money(amount: Decimal(shares) * sh.holding.currentPrice, currency: sh.holding.currency)
            let valueDisplay = sh.holding.currentValueMoney.converted(to: totalValue.currency, using: rates)
            let valueAfter = valueDisplay.amount + actualAmountBudget

            suggestions.append(RebalancingSuggestion(
                ticker: sh.holding.ticker,
                displayName: sh.holding.displayName,
                sharesToBuy: shares,
                amount: nativeAmount,
                currentPercent: percent(of: valueDisplay.amount, total: totalValue.amount),
                targetPercent: sh.classTarget,
                newPercent: percent(of: valueAfter, total: newTotalValue.amount)
            ))
            remaining -= actualAmountBudget
        }

        if remaining > 0 {
            for sh in scored {
                guard remaining >= sh.pricePerShareInBudgetCurrency else { continue }
                let extraShares = Int(NSDecimalNumber(decimal: remaining / sh.pricePerShareInBudgetCurrency).doubleValue)
                guard extraShares > 0 else { continue }

                let extraAmountBudget = Decimal(extraShares) * sh.pricePerShareInBudgetCurrency
                let extraNative = Money(amount: Decimal(extraShares) * sh.holding.currentPrice, currency: sh.holding.currency)

                if let idx = suggestions.firstIndex(where: { $0.ticker == sh.holding.ticker }) {
                    let old = suggestions[idx]
                    let valueDisplay = sh.holding.currentValueMoney.converted(to: totalValue.currency, using: rates)
                    let oldBudgetAmount = old.amount.converted(to: totalValue.currency, using: rates).amount
                    suggestions[idx] = RebalancingSuggestion(
                        ticker: old.ticker,
                        displayName: old.displayName,
                        sharesToBuy: old.sharesToBuy + extraShares,
                        amount: old.amount + extraNative,
                        currentPercent: old.currentPercent,
                        targetPercent: old.targetPercent,
                        newPercent: percent(of: valueDisplay.amount + oldBudgetAmount + extraAmountBudget, total: newTotalValue.amount)
                    )
                } else {
                    let valueDisplay = sh.holding.currentValueMoney.converted(to: totalValue.currency, using: rates)
                    suggestions.append(RebalancingSuggestion(
                        ticker: sh.holding.ticker,
                        displayName: sh.holding.displayName,
                        sharesToBuy: extraShares,
                        amount: extraNative,
                        currentPercent: percent(of: valueDisplay.amount, total: totalValue.amount),
                        targetPercent: sh.classTarget,
                        newPercent: percent(of: valueDisplay.amount + extraAmountBudget, total: newTotalValue.amount)
                    ))
                }
                remaining -= extraAmountBudget
                break
            }
        }

        // Sort by amount in budget currency to keep ranking consistent across currencies
        return suggestions.sorted {
            $0.amount.converted(to: totalValue.currency, using: rates).amount
                > $1.amount.converted(to: totalValue.currency, using: rates).amount
        }
    }

    private static func percent(of value: Decimal, total: Decimal) -> Decimal {
        guard total > 0 else { return 0 }
        return (value / total) * 100
    }
}
