import Testing
import Foundation
@testable import Tranquilidade

struct RebalancingEngineTests {

    // MARK: - Two-tier: class allocation drives distribution

    @Test func investsInMostUnderweightClass() {
        // Acoes BR 60% target, FIIs 40% target
        // Current: each 1000 (50%) → Acoes BR underweight by 10%
        let holdings = [
            Holding(ticker: "ITUB3", quantity: 100, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "XPML11", quantity: 100, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 60, .fiis: 40]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: 1000, classAllocations: classAlloc
        )

        let acoes = suggestions.first { $0.ticker == "ITUB3" }
        #expect(acoes != nil, "Underweight class should receive investment")
        #expect(acoes!.sharesToBuy > 0)
    }

    @Test func classAtTargetStillRecommends() {
        // Both classes at target — engine should still recommend (least overweight)
        let holdings = [
            Holding(ticker: "A", quantity: 100, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "B", quantity: 100, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 50, .fiis: 50]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: 1000, classAllocations: classAlloc
        )
        #expect(!suggestions.isEmpty, "Always recommends — picks least overweight")
    }

    @Test func underweightClassRanksHigher() {
        // Acoes BR at 33%, target 30% → overweight
        // FIIs at 67%, target 70% → underweight → ranked first
        let holdings = [
            Holding(ticker: "ITUB3", quantity: 100, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "XPML11", quantity: 200, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 30, .fiis: 70]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: 1000, classAllocations: classAlloc
        )

        #expect(suggestions.first { $0.ticker == "XPML11" } != nil, "Underweight class receives")
    }

    // MARK: - Within class: holding weight distribution

    @Test func budgetSplitEquallyAcrossRecommendations() {
        // Two holdings, budget split equally: 1000/2 = 500 each → 50 shares each
        let holdings = [
            Holding(ticker: "HIGH", quantity: 1, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 20),
            Holding(ticker: "LOW", quantity: 1, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 100]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: 1000, classAllocations: classAlloc
        )

        let high = suggestions.first { $0.ticker == "HIGH" }
        let low = suggestions.first { $0.ticker == "LOW" }
        #expect(high != nil && low != nil, "Both should receive investment")
        if let h = high, let l = low {
            #expect(h.sharesToBuy == 50, "500/10 = 50 shares")
            #expect(l.sharesToBuy == 50, "500/10 = 50 shares")
        }
    }

    @Test func equalPriceGetsEqualShares() {
        // Two holdings, same price, budget split equally
        let holdings = [
            Holding(ticker: "A", quantity: 10, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "B", quantity: 10, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 100]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: 2000, classAllocations: classAlloc
        )

        let a = suggestions.first { $0.ticker == "A" }
        let b = suggestions.first { $0.ticker == "B" }
        #expect(a != nil && b != nil)
        if let a, let b {
            #expect(a.sharesToBuy == b.sharesToBuy, "Equal split = equal shares")
        }
    }

    // MARK: - Frozen / quarantine exclusion

    @Test func excludesFrozenHoldings() {
        // Frozen holding counts toward class value but doesn't receive money
        let holdings = [
            Holding(ticker: "FROZEN", quantity: 50, currentPrice: 10,
                    assetClass: .acoesBR, status: .congelar, targetPercent: 5),
            Holding(ticker: "ACTIVE", quantity: 50, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            // Other class to create underweight
            Holding(ticker: "FII", quantity: 200, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        // Total = 3000. Acoes BR = 1000 (33%), target 60% → underweight
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 60, .fiis: 40]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: 1000, classAllocations: classAlloc
        )

        #expect(suggestions.first { $0.ticker == "FROZEN" } == nil, "Frozen excluded")
        #expect(suggestions.first { $0.ticker == "ACTIVE" } != nil, "Active receives")
    }

    @Test func excludesQuarantineHoldings() {
        let holdings = [
            Holding(ticker: "Q", quantity: 50, currentPrice: 10,
                    assetClass: .acoesBR, status: .quarentena, targetPercent: 5),
            Holding(ticker: "A", quantity: 50, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "F", quantity: 200, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 60, .fiis: 40]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: 500, classAllocations: classAlloc
        )
        #expect(suggestions.first { $0.ticker == "Q" } == nil)
        #expect(suggestions.first { $0.ticker == "A" } != nil)
    }

    @Test func returnsEmptyWhenAllFrozen() {
        let holdings = [
            Holding(ticker: "A", quantity: 100, currentPrice: 10,
                    assetClass: .acoesBR, status: .congelar, targetPercent: 5),
        ]
        // Class is underweight but no eligible holdings
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 100]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: 5000, classAllocations: classAlloc
        )
        #expect(suggestions.isEmpty)
    }

    // MARK: - Edge cases

    @Test func zeroInvestmentReturnsEmpty() {
        let holdings = [
            Holding(ticker: "A", quantity: 100, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
        ]
        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: 0, classAllocations: [.acoesBR: 100]
        )
        #expect(suggestions.isEmpty)
    }

    @Test func roundsToWholeShares() {
        let holdings = [
            Holding(ticker: "EXP", quantity: 1, currentPrice: 300,
                    assetClass: .usStocks, status: .aportar, targetPercent: 5),
        ]
        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: 500, classAllocations: [.usStocks: 100]
        )

        if let s = suggestions.first {
            #expect(s.sharesToBuy == 1)
            #expect(s.amount == 300)
        }
    }

    @Test func fallbackWithoutClassAllocations() {
        let holdings = [
            Holding(ticker: "A", quantity: 100, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 10),
            Holding(ticker: "B", quantity: 50, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: 1000
        )
        #expect(!suggestions.isEmpty, "Fallback should produce suggestions")
    }

    @Test func handlesUSDHoldingsWithExchangeRate() {
        let holdings = [
            Holding(ticker: "AAPL", quantity: 10, currentPrice: 100,
                    assetClass: .usStocks, currency: .usd, status: .aportar, targetPercent: 5),
        ]
        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: 5000,
            classAllocations: [.usStocks: 100], exchangeRate: 5
        )
        #expect(!suggestions.isEmpty)
        if let s = suggestions.first {
            #expect(s.sharesToBuy == 10, "10 shares × R$500 = R$5000")
        }
    }

    @Test func maxRecommendationsLimitsSuggestions() {
        let holdings = [
            Holding(ticker: "A", quantity: 10, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "B", quantity: 10, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
            Holding(ticker: "C", quantity: 10, currentPrice: 10,
                    assetClass: .usStocks, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 34, .fiis: 33, .usStocks: 33]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: 3000,
            classAllocations: classAlloc, maxRecommendations: 2
        )

        #expect(suggestions.count == 2, "Should limit to 2 recommendations")
        // Budget split: 3000/2 = 1500 each → 150 shares at R$10
        let totalShares = suggestions.reduce(0) { $0 + $1.sharesToBuy }
        #expect(totalShares == 300, "1500/10 × 2 = 300 total shares")
    }

    // MARK: - Portfolio class allocation storage

    @Test func portfolioClassAllocationsRoundTrip() {
        let portfolio = Portfolio(name: "Test")
        let alloc: [AssetClassType: Double] = [.acoesBR: 40, .fiis: 30, .usStocks: 30]

        portfolio.classAllocations = alloc
        let loaded = portfolio.classAllocations

        #expect(loaded[.acoesBR] == 40)
        #expect(loaded[.fiis] == 30)
        #expect(loaded[.usStocks] == 30)
        #expect(loaded.values.reduce(0, +) == 100)
    }

    @Test func emptyPortfolioReturnsEmptyAllocations() {
        let portfolio = Portfolio(name: "Empty")
        #expect(portfolio.classAllocations.isEmpty)
    }
}
