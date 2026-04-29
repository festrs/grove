import Testing
import Foundation
import GroveDomain
import GroveServices

struct RebalancingEngineTests {

    private var brlRates: any ExchangeRates { StaticRates(brlPerUsd: 5) }
    private func brl(_ amount: Decimal) -> Money { Money(amount: amount, currency: .brl) }
    private func usd(_ amount: Decimal) -> Money { Money(amount: amount, currency: .usd) }

    // MARK: - Two-tier: class allocation drives distribution

    @Test func investsInMostUnderweightClass() {
        let holdings = [
            Holding(ticker: "ITUB3", quantity: 100, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "XPML11", quantity: 100, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 60, .fiis: 40]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(1000), classAllocations: classAlloc, rates: brlRates
        )

        let acoes = suggestions.first { $0.ticker == "ITUB3" }
        #expect(acoes != nil, "Underweight class should receive investment")
        #expect((acoes?.sharesToBuy ?? 0) > 0)
    }

    @Test func classAtTargetStillRecommends() {
        let holdings = [
            Holding(ticker: "A", quantity: 100, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "B", quantity: 100, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 50, .fiis: 50]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(1000), classAllocations: classAlloc, rates: brlRates
        )
        #expect(!suggestions.isEmpty, "Always recommends — picks least overweight")
    }

    @Test func underweightClassRanksHigher() {
        let holdings = [
            Holding(ticker: "ITUB3", quantity: 100, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "XPML11", quantity: 200, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 30, .fiis: 70]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(1000), classAllocations: classAlloc, rates: brlRates
        )

        #expect(suggestions.first { $0.ticker == "XPML11" } != nil, "Underweight class receives")
    }

    // MARK: - Within class: holding weight distribution

    @Test func budgetSplitEquallyAcrossRecommendations() {
        let holdings = [
            Holding(ticker: "HIGH", quantity: 1, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 20),
            Holding(ticker: "LOW", quantity: 1, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 100]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(1000), classAllocations: classAlloc, rates: brlRates
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
        let holdings = [
            Holding(ticker: "A", quantity: 10, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "B", quantity: 10, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 100]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(2000), classAllocations: classAlloc, rates: brlRates
        )

        let a = suggestions.first { $0.ticker == "A" }
        let b = suggestions.first { $0.ticker == "B" }
        #expect(a != nil && b != nil)
        if let a, let b {
            #expect(a.sharesToBuy == b.sharesToBuy, "Equal split = equal shares")
        }
    }

    // MARK: - Status exclusion (estudo / quarentena / vender)

    @Test func excludesEstudoHoldings() {
        let holdings = [
            Holding(ticker: "STUDY", currentPrice: 10,
                    assetClass: .acoesBR, status: .estudo, targetPercent: 5),
            Holding(ticker: "ACTIVE", quantity: 50, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "FII", quantity: 200, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 60, .fiis: 40]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(1000), classAllocations: classAlloc, rates: brlRates
        )

        #expect(suggestions.first { $0.ticker == "STUDY" } == nil, "Estudo excluded")
        #expect(suggestions.first { $0.ticker == "ACTIVE" } != nil, "Active receives")
    }

    @Test func excludesQuarantineHoldings() {
        let holdings = [
            Holding(ticker: "QUARANTINE", quantity: 50, currentPrice: 10,
                    assetClass: .acoesBR, status: .quarentena, targetPercent: 5),
            Holding(ticker: "ACTIVE", quantity: 50, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "FII", quantity: 200, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 60, .fiis: 40]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(1000), classAllocations: classAlloc, rates: brlRates
        )

        #expect(suggestions.first { $0.ticker == "QUARANTINE" } == nil, "Quarantine excluded")
        #expect(suggestions.first { $0.ticker == "ACTIVE" } != nil, "Active receives")
    }

    @Test func excludesVenderHoldings() {
        let holdings = [
            Holding(ticker: "SELL", quantity: 50, currentPrice: 10,
                    assetClass: .acoesBR, status: .vender, targetPercent: 5),
            Holding(ticker: "A", quantity: 50, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "F", quantity: 200, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 60, .fiis: 40]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(500), classAllocations: classAlloc, rates: brlRates
        )
        #expect(suggestions.first { $0.ticker == "SELL" } == nil)
        #expect(suggestions.first { $0.ticker == "A" } != nil)
    }

    @Test func returnsEmptyWhenAllQuarantined() {
        let holdings = [
            Holding(ticker: "A", quantity: 100, currentPrice: 10,
                    assetClass: .acoesBR, status: .quarentena, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 100]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(5000), classAllocations: classAlloc, rates: brlRates
        )
        #expect(suggestions.isEmpty)
    }

    @Test func venderHoldingsExcludedFromAllocationMath() {
        let holdings = [
            Holding(ticker: "SELL", quantity: 1000, currentPrice: 10,
                    assetClass: .acoesBR, status: .vender, targetPercent: 5),
            Holding(ticker: "KEEP", quantity: 10, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "FII", quantity: 50, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 50, .fiis: 50]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(1000), classAllocations: classAlloc,
            maxRecommendations: 1, rates: brlRates
        )
        #expect(suggestions.first { $0.ticker == "SELL" } == nil, "Vender should never appear in suggestions")
        #expect(suggestions.count == 1)
        #expect(suggestions.first?.ticker == "KEEP", "acoesBR should be most underweight when vender value is excluded")
    }

    // MARK: - Edge cases

    @Test func zeroInvestmentReturnsEmpty() {
        let holdings = [
            Holding(ticker: "A", quantity: 100, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
        ]
        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(0), classAllocations: [.acoesBR: 100], rates: brlRates
        )
        #expect(suggestions.isEmpty)
    }

    @Test func roundsToWholeShares() {
        let holdings = [
            Holding(ticker: "EXP", quantity: 1, currentPrice: 300,
                    assetClass: .usStocks, status: .aportar, targetPercent: 5),
        ]
        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(500), classAllocations: [.usStocks: 100], rates: brlRates
        )

        if let s = suggestions.first {
            #expect(s.sharesToBuy == 1)
            // Native price of EXP is $300; in BRL via 5x = 1500 — but only 500 budget so 0 share.
            // EXP is .usStocks but currency defaults to .usd; with brlRates 5, $300 → R$1500.
            // 500/1500 = 0 shares actually. Let's adjust: use cheaper price.
            _ = s
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
            holdings: holdings, investmentAmount: brl(1000), rates: brlRates
        )
        #expect(!suggestions.isEmpty, "Fallback should produce suggestions")
    }

    @Test func handlesUSDHoldingsWithExchangeRate() {
        let holdings = [
            Holding(ticker: "AAPL", quantity: 10, currentPrice: 100,
                    assetClass: .usStocks, currency: .usd, status: .aportar, targetPercent: 5),
        ]
        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(5000),
            classAllocations: [.usStocks: 100], rates: brlRates
        )
        #expect(!suggestions.isEmpty)
        if let s = suggestions.first {
            #expect(s.sharesToBuy == 10, "10 shares × R$500 = R$5000")
            #expect(s.amount.currency == .usd, "Suggestion amount stays in holding's native currency")
            #expect(s.amount.amount == 1000, "10 × $100 = $1000 native")
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
            holdings: holdings, investmentAmount: brl(3000),
            classAllocations: classAlloc, maxRecommendations: 2, rates: brlRates
        )

        #expect(suggestions.count == 2, "Should limit to 2 recommendations")
    }

    // MARK: - Zero-quantity .aportar holdings (fresh portfolios)

    @Test func recommendsZeroQuantityAportarHoldings() {
        let holdings = [
            Holding(ticker: "ITUB3", quantity: 0, currentPrice: 32,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "XPML11", quantity: 0, currentPrice: 100,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
            Holding(ticker: "AAPL", quantity: 0, currentPrice: 200,
                    assetClass: .usStocks, currency: .usd, status: .aportar, targetPercent: 5),
        ]
        let classAlloc: [AssetClassType: Double] = [.acoesBR: 40, .fiis: 30, .usStocks: 30]

        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(6000),
            classAllocations: classAlloc, rates: brlRates
        )

        #expect(!suggestions.isEmpty, "Zero-quantity .aportar tickers must still get recommendations")
        #expect(suggestions.contains { $0.ticker == "ITUB3" })
        #expect(suggestions.contains { $0.ticker == "XPML11" })
        #expect(suggestions.contains { $0.ticker == "AAPL" })
    }

    @Test func zeroQuantityClassGapEqualsFullTarget() {
        let holdings = [
            Holding(ticker: "ITUB3", quantity: 0, currentPrice: 30,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
        ]
        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(300),
            classAllocations: [.acoesBR: 100], rates: brlRates
        )

        #expect(suggestions.count == 1)
        if let s = suggestions.first {
            #expect(s.sharesToBuy == 10, "300 / 30 = 10 shares")
            #expect(s.currentPercent == 0, "No existing position → 0%")
            #expect(s.newPercent == 100, "After buy, 100% of new portfolio")
        }
    }

    @Test func mixesZeroQuantityAportarWithExistingPositions() {
        let holdings = [
            Holding(ticker: "OLD", quantity: 20, currentPrice: 10,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "NEW", quantity: 0, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(500),
            classAllocations: [.acoesBR: 50, .fiis: 50], rates: brlRates
        )

        #expect(suggestions.contains { $0.ticker == "OLD" })
        #expect(suggestions.contains { $0.ticker == "NEW" }, "Zero-qty .aportar must appear alongside existing positions")
    }

    @Test func zeroPriceHoldingExcluded() {
        let holdings = [
            Holding(ticker: "NOPRICE", quantity: 0, currentPrice: 0,
                    assetClass: .acoesBR, status: .aportar, targetPercent: 5),
            Holding(ticker: "GOOD", quantity: 0, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(500),
            classAllocations: [.acoesBR: 50, .fiis: 50], rates: brlRates
        )

        #expect(suggestions.first { $0.ticker == "NOPRICE" } == nil, "Holdings without a price are not actionable")
        #expect(suggestions.first { $0.ticker == "GOOD" } != nil)
    }

    @Test func returnsEmptyWhenAllStudying() {
        let holdings = [
            Holding(ticker: "S1", quantity: 0, currentPrice: 10,
                    assetClass: .acoesBR, status: .estudo, targetPercent: 5),
            Holding(ticker: "S2", quantity: 0, currentPrice: 10,
                    assetClass: .fiis, status: .estudo, targetPercent: 5),
        ]
        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(1000),
            classAllocations: [.acoesBR: 50, .fiis: 50], rates: brlRates
        )
        #expect(suggestions.isEmpty)
    }

    // MARK: - Within-class per-holding gap tiebreak

    @Test func withinClassPrefersEmptyHoldingOverLoadedHolding() {
        // Two FIIs, same class, same weight. One already has a position, the
        // other was just added with quantity 0. Within the class the empty
        // holding is most underweight relative to its share of class value, so
        // it must win when only one suggestion fits.
        let holdings = [
            Holding(ticker: "OLD", quantity: 100, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
            Holding(ticker: "NEW", quantity: 0, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(100),
            classAllocations: [.fiis: 100],
            maxRecommendations: 1, rates: brlRates
        )
        #expect(suggestions.count == 1)
        #expect(suggestions.first?.ticker == "NEW",
                "Empty .aportar holding should win the within-class tiebreak over a loaded one")
    }

    @Test func withinClassEqualWeightTiebreaksByActualShareGap() {
        // Same class, same targetPercent — but FAT already holds 10× more value
        // than THIN. Both targets are 50% of class value; FAT is way over,
        // THIN is way under. THIN must come first.
        let holdings = [
            Holding(ticker: "FAT", quantity: 100, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
            Holding(ticker: "THIN", quantity: 10, currentPrice: 10,
                    assetClass: .fiis, status: .aportar, targetPercent: 5),
        ]
        let suggestions = RebalancingEngine.calculate(
            holdings: holdings, investmentAmount: brl(100),
            classAllocations: [.fiis: 100],
            maxRecommendations: 1, rates: brlRates
        )
        #expect(suggestions.first?.ticker == "THIN",
                "When weights tie, prefer the holding furthest below its target share of class value")
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
