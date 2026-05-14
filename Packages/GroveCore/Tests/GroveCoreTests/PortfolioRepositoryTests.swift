import Testing
import Foundation
import SwiftData
import GroveDomain
import GroveRepositories

@MainActor
struct PortfolioRepositoryTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([Portfolio.self, Holding.self, UserSettings.self, DividendPayment.self, Contribution.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - Holding.currentPercent (allocation math used by views)

    @Test func currentPercentReturnsHoldingShareOfTotal() {
        let h = Holding(ticker: "ITUB3", quantity: 10, currentPrice: 100,
                        assetClass: .acoesBR, status: .aportar)
        // currentValue = 1000 BRL, totalValue = 4000 BRL → 25%.
        // If the empty-guard is inverted, this returns 0 instead of 25.
        let pct = h.currentPercent(
            of: Money(amount: 4000, currency: .brl),
            in: .brl, rates: Self.rates
        )
        #expect(pct == 25)
    }

    @Test func currentPercentReturnsZeroForEmptyPortfolio() {
        let h = Holding(ticker: "ITUB3", quantity: 10, currentPrice: 100,
                        assetClass: .acoesBR, status: .aportar)
        let pct = h.currentPercent(
            of: Money(amount: 0, currency: .brl),
            in: .brl, rates: Self.rates
        )
        #expect(pct == 0)
    }

    @Test func driftIsPositiveWhenOverweight() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "ITUB3", quantity: 100, currentPrice: 30, assetClass: .acoesBR, status: .aportar, targetPercent: 5)
        ctx.insert(h)
        try? ctx.save()

        let repo = PortfolioRepository(modelContext: ctx)
        let summary = repo.computeSummary(
            holdings: [h],
            classAllocations: [.acoesBR: 20],
            displayCurrency: .brl,
            rates: Self.rates
        )

        let acoesBRAlloc = summary.allocationByClass.first { $0.assetClass == .acoesBR }
        #expect(acoesBRAlloc != nil)
        #expect((acoesBRAlloc?.drift ?? 0) > 0, "Overweight class should have positive drift")
    }

    @Test func computeSummaryAlwaysEmitsAllSixClasses() throws {
        let ctx = try Self.makeContext()
        let repo = PortfolioRepository(modelContext: ctx)
        let summary = repo.computeSummary(
            holdings: [],
            classAllocations: [:],
            displayCurrency: .brl,
            rates: Self.rates
        )

        // The Portfolio tab needs every class to render even with zero holdings
        // and zero targets, so the user can drill into any class to add tickers.
        #expect(summary.allocationByClass.count == AssetClassType.allCases.count)
        for cls in AssetClassType.allCases {
            #expect(summary.allocationByClass.contains { $0.assetClass == cls })
        }
    }

    @Test func saveOnboardingPortfolioPersistsAllSixWeights() throws {
        let ctx = try Self.makeContext()
        let repo = PortfolioRepository(modelContext: ctx)

        let pending = [
            PendingHolding(ticker: "ITUB3", displayName: "Itaú", quantity: 0,
                           assetClass: .acoesBR, status: .estudo,
                           currentPrice: 30, dividendYield: 0)
        ]
        let allocations: [AssetClassType: Decimal] = [
            .acoesBR: 30, .fiis: 25, .usStocks: 15, .reits: 10, .crypto: 5, .rendaFixa: 15
        ]

        let plan = PortfolioRepository.FreedomPlanInput(
            monthlyCostOfLiving: 8_000,
            costOfLivingCurrency: .brl,
            targetFIYear: 2046,
            incomeMode: .lifestyle,
            monthlyContributionCapacity: 3_000,
            contributionCurrency: .brl,
            currencyMixBRLPercent: 70,
            freedomNumber: Money(amount: 12_000, currency: .brl)
        )
        _ = try repo.saveOnboardingPortfolio(
            preferredName: "Test",
            nameFallbacks: ["Fallback"],
            pendingHoldings: pending,
            targetAllocations: allocations,
            freedomPlan: plan
        )

        let settings = try repo.fetchSettings()
        // Even though only acoesBR has holdings, all 6 weights persist so the
        // Settings view reflects what the user set during onboarding.
        #expect(settings.classAllocations.count == AssetClassType.allCases.count)
        #expect(settings.classAllocations[.fiis] == 25)
        #expect(settings.classAllocations[.crypto] == 5)
    }

    @Test func saveOnboardingPortfolioPersistsFreedomPlan() throws {
        let ctx = try Self.makeContext()
        let repo = PortfolioRepository(modelContext: ctx)

        let plan = PortfolioRepository.FreedomPlanInput(
            monthlyCostOfLiving: 6_000,
            costOfLivingCurrency: .brl,
            targetFIYear: 2050,
            incomeMode: .lifestylePlusBuffer,
            monthlyContributionCapacity: 4_500,
            contributionCurrency: .brl,
            currencyMixBRLPercent: 60,
            freedomNumber: Money(amount: 12_000, currency: .brl)
        )
        _ = try repo.saveOnboardingPortfolio(
            preferredName: "Plan Test",
            nameFallbacks: ["Plan Fallback"],
            pendingHoldings: [],
            targetAllocations: [.acoesBR: 100],
            freedomPlan: plan
        )

        let settings = try repo.fetchSettings()
        #expect(settings.monthlyIncomeGoal == 12_000)
        #expect(settings.targetFIYear == 2050)
        #expect(settings.fiIncomeMode == .lifestylePlusBuffer)
        #expect(settings.costAtFIMultiplier == 2.0)
        #expect(settings.monthlyContributionCapacity == 4_500)
        #expect(settings.fiCurrencyMixBRLPercent == 60)
        #expect(settings.freedomPlanCompletedAt != nil,
                "completedAt must be stamped so the dashboard nudge banner stays hidden after onboarding.")
    }

    @Test func driftIsNegativeWhenUnderweight() throws {
        let ctx = try Self.makeContext()
        let h1 = Holding(ticker: "ITUB3", quantity: 10, currentPrice: 10, assetClass: .acoesBR, status: .aportar, targetPercent: 5)
        let h2 = Holding(ticker: "KNRI11", quantity: 100, currentPrice: 100, assetClass: .fiis, status: .aportar, targetPercent: 5)
        ctx.insert(h1)
        ctx.insert(h2)
        try? ctx.save()

        let repo = PortfolioRepository(modelContext: ctx)
        let summary = repo.computeSummary(
            holdings: [h1, h2],
            classAllocations: [.acoesBR: 80, .fiis: 20],
            displayCurrency: .brl,
            rates: Self.rates
        )

        let acoesBRAlloc = summary.allocationByClass.first { $0.assetClass == .acoesBR }
        #expect(acoesBRAlloc != nil)
        #expect((acoesBRAlloc?.drift ?? 0) < 0, "Underweight class should have negative drift")
    }

    // MARK: - monthlyIncomeGross aggregation (TTM-based with yield fallback)

    private static let utcCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private static let summaryAsOf: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 29; c.hour = 12
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    /// Build a holding with N monthly dividend payments inside the trailing-12m
    /// window relative to `summaryAsOf`. Each payment is shifted +1 day past
    /// the month boundary so the oldest one stays strictly inside the window.
    private static func seedHolding(
        in ctx: ModelContext,
        ticker: String,
        qty: Decimal,
        price: Decimal,
        currency: Currency,
        assetClass: AssetClassType,
        yield: Decimal,
        ttmMonthlyDividendsPerShare: Decimal? = nil,
        firstBuyMonthsAgo: Int = 18
    ) -> Holding {
        let h = Holding(
            ticker: ticker, quantity: qty, currentPrice: price,
            dividendYield: yield, assetClass: assetClass, currency: currency,
            status: .aportar
        )
        ctx.insert(h)
        let firstBuy = utcCal.date(byAdding: .month, value: -firstBuyMonthsAgo, to: summaryAsOf)!
        let contrib = Contribution(date: firstBuy, amount: qty * price, shares: qty, pricePerShare: price)
        ctx.insert(contrib); contrib.holding = h
        if let amt = ttmMonthlyDividendsPerShare {
            for offset in 1...12 {
                let monthBack = utcCal.date(byAdding: .month, value: -offset, to: summaryAsOf)!
                let payDate = utcCal.date(byAdding: .day, value: 1, to: monthBack)!
                let exDate = utcCal.date(byAdding: .day, value: -2, to: payDate)!
                let p = DividendPayment(exDate: exDate, paymentDate: payDate, amountPerShare: amt)
                ctx.insert(p); p.holding = h
            }
        }
        return h
    }

    @Test func summaryUsesTTMPathWhenRecordsExistAndYieldFallbackOtherwise() throws {
        let ctx = try Self.makeContext()
        // H1 — has 12 records of R$1/share × 100 shares → TTM monthly = R$100.
        let h1 = Self.seedHolding(in: ctx, ticker: "FII1", qty: 100, price: 100,
                                  currency: .brl, assetClass: .fiis, yield: 0,
                                  ttmMonthlyDividendsPerShare: 1)
        // H2 — no records, dy=6%, 100 × 50 = R$5000 value → fallback monthly = 5000 × 0.06 / 12 = R$25.
        let h2 = Self.seedHolding(in: ctx, ticker: "STK2", qty: 100, price: 50,
                                  currency: .brl, assetClass: .acoesBR, yield: 6)

        let repo = PortfolioRepository(modelContext: ctx)
        let summary = repo.computeSummary(
            holdings: [h1, h2],
            classAllocations: [:],
            displayCurrency: .brl,
            rates: Self.rates,
            asOf: Self.summaryAsOf
        )

        // Card must equal Σ(per-holding monthly): 100 (TTM) + 25 (yield fallback) = 125.
        #expect(summary.monthlyIncomeGross.amount == 125)
        #expect(summary.monthlyIncomeGross.currency == .brl)
    }

    @Test func summaryFXConversionWithMixedCurrencies() throws {
        let ctx = try Self.makeContext()
        // BRL FII: TTM monthly = R$100 (native).
        let brlH = Self.seedHolding(in: ctx, ticker: "FII1", qty: 100, price: 100,
                                    currency: .brl, assetClass: .fiis, yield: 0,
                                    ttmMonthlyDividendsPerShare: 1)
        // USD stock: TTM monthly = $20 (10 shares × $2/share/month).
        let usdH = Self.seedHolding(in: ctx, ticker: "AAPL", qty: 10, price: 100,
                                    currency: .usd, assetClass: .usStocks, yield: 0,
                                    ttmMonthlyDividendsPerShare: 2)

        let repo = PortfolioRepository(modelContext: ctx)
        let summary = repo.computeSummary(
            holdings: [brlH, usdH],
            classAllocations: [:],
            displayCurrency: .brl,
            rates: Self.rates, // brlPerUsd = 5
            asOf: Self.summaryAsOf
        )

        // 100 BRL + ($20 × 5) = 100 + 100 = R$200.
        #expect(summary.monthlyIncomeGross.amount == 200)
        #expect(summary.monthlyIncomeGross.currency == .brl)
    }
}
