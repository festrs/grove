import Testing
import Foundation
import SwiftData
import GroveDomain
import GroveServices

@MainActor
struct IncomeProjectorTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)
    private static var brlGoal: Money { Money(amount: 1000, currency: .brl) }
    private static var brlContribution: Money { Money(amount: 5_000, currency: .brl) }

    private static let utcCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// 2026-04-29 14:30 UTC.
    private static let asOf: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 29
        c.hour = 14; c.minute = 30
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([Portfolio.self, Holding.self, UserSettings.self, DividendPayment.self, Contribution.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private static func aprilDate(_ day: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = day; c.hour = 12
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private static func janFirst() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 1
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    /// Seed a holding + a contribution at Jan 1 + a dividend record with
    /// `paymentDate` in April so it counts toward the asOf month window.
    private static func makeHolding(
        in ctx: ModelContext,
        ticker: String,
        qty: Decimal,
        price: Decimal,
        dy: Decimal,
        assetClass: AssetClassType,
        currency: Currency? = nil,
        targetPercent: Decimal = 100,
        aprilDividendPerShare: Decimal? = nil
    ) -> Holding {
        let h = Holding(ticker: ticker, quantity: qty, currentPrice: price,
                        dividendYield: dy, assetClass: assetClass, currency: currency,
                        status: .aportar, targetPercent: targetPercent)
        ctx.insert(h)
        let contrib = Contribution(date: janFirst(), amount: 1, shares: qty, pricePerShare: price)
        ctx.insert(contrib); contrib.holding = h
        if let amt = aprilDividendPerShare {
            // ex-date past asOf so it counts as paid; payment-date in April so it's in month window.
            let p = DividendPayment(exDate: aprilDate(10), paymentDate: aprilDate(15), amountPerShare: amt)
            ctx.insert(p); p.holding = h
        }
        return h
    }

    // MARK: - Basic Projection (real-record driven)

    @Test func projectsCurrentIncomeFromDividendRecords() throws {
        let ctx = try Self.makeContext()
        // 100 shares × 1/share dividend in April → 100 BRL gross monthly
        let h = Self.makeHolding(in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 12,
                                 assetClass: .fiis, aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h], incomeGoal: Self.brlGoal,
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )

        #expect(projection.currentMonthlyGross.amount == 100)
        #expect(projection.currentMonthlyGross.currency == .brl)
        #expect(projection.currentMonthlyNet.amount == 100, "FIIs are tax-exempt")
        #expect(projection.goalMonthly.amount == 1000)
    }

    @Test func progressPercentMatchesNetOverGoal() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 12,
                                 assetClass: .fiis, aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h], incomeGoal: Self.brlGoal,
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        // 100 / 1000 * 100 = 10
        #expect(projection.progressPercent == 10)
    }

    @Test func goalSimUsesDYFromHoldings() throws {
        // Real records: 100 BRL/mo gross. Goal: 1000 BRL/mo.
        // Sim: total value = 10000 BRL, est annual gross = (100 * 100 * 12%) = 1200,
        // avgDY = (1200 / 10000) * 100 = 12%; monthly yield = 0.01.
        // contribution = 5000 BRL × 0.01 × 1.0 = 50 BRL/mo added per iteration.
        // Starting at 100 net, needs (1000 - 100) / 50 = 18 months.
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 12,
                                 assetClass: .fiis, aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h], incomeGoal: Self.brlGoal,
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )

        #expect(projection.estimatedMonthsToGoal == 18,
                "Loop must run when net < goal — mutation flipping < to > would skip and return nil")
        #expect(projection.estimatedYearsToGoal == Decimal(18) / 12)
    }

    @Test func goalReachedShowsZeroMonths() throws {
        let ctx = try Self.makeContext()
        // 1000 shares × 1/share = 1000 BRL/mo, goal = 500 → already past goal
        let h = Self.makeHolding(in: ctx, ticker: "FII1", qty: 1000, price: 100, dy: 12,
                                 assetClass: .fiis, aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h],
            incomeGoal: Money(amount: 500, currency: .brl),
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )

        #expect(projection.estimatedMonthsToGoal == 0)
        #expect(projection.progressPercent == 100)
    }

    @Test func emptyPortfolioReturnsZero() {
        let projection = IncomeProjector.project(
            holdings: [],
            incomeGoal: Money(amount: 10_000, currency: .brl),
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )

        #expect(projection.currentMonthlyGross.amount == 0)
        #expect(projection.currentMonthlyNet.amount == 0)
        #expect(projection.progressPercent == 0)
    }

    @Test func zeroDividendRecordsYieldsZeroCurrent() throws {
        // Holding has DY% but no DividendPayment records — currentMonthly is 0.
        // (DY% only enters the goal-sim loop, not the displayed current value.)
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 12,
                                 assetClass: .fiis, aprilDividendPerShare: nil)
        let projection = IncomeProjector.project(
            holdings: [h], incomeGoal: Self.brlGoal,
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(projection.currentMonthlyGross.amount == 0)
        #expect(projection.currentMonthlyNet.amount == 0)
        // Sim still runs because contribution > 0 and net < goal
        #expect(projection.estimatedMonthsToGoal != nil)
    }

    // MARK: - Tax Impact

    @Test func usStocksReduceNetIncome() throws {
        let ctx = try Self.makeContext()
        // 100 shares × 1 USD dividend in April → 100 USD = 500 BRL gross.
        // US stocks = 30% withholding → 350 BRL net.
        let h = Self.makeHolding(in: ctx, ticker: "AAPL", qty: 100, price: 100, dy: 12,
                                 assetClass: .usStocks, currency: .usd,
                                 aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h],
            incomeGoal: Money(amount: 10_000, currency: .brl),
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )

        #expect(projection.currentMonthlyGross.amount == 500)
        #expect(projection.currentMonthlyNet.amount == 350)
    }

    // MARK: - Mixed Portfolio

    @Test func mixedPortfolioAggregatesCorrectly() throws {
        let ctx = try Self.makeContext()
        let fii = Self.makeHolding(in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 12,
                                   assetClass: .fiis, targetPercent: 50,
                                   aprilDividendPerShare: 1)
        // 100 BRL FII + 50 USD US = 100 + 250 = 350 BRL gross
        // FII: 100 net (exempt). US: 250 × 0.7 = 175 net. Total net = 275? Hmm.
        // Wait: previous test had 125 gross / 117.5 net for tiny US portion. Let me size to match.
        // FII: 100 shares × 1 BRL = 100 BRL gross. US: 10 shares × 0.5 USD = 5 USD = 25 BRL gross.
        // Total gross = 125. US net = 25 × 0.7 = 17.5. FII net = 100. Total net = 117.5.
        let us = Self.makeHolding(in: ctx, ticker: "US1", qty: 10, price: 100, dy: 6,
                                  assetClass: .usStocks, currency: .usd, targetPercent: 50,
                                  aprilDividendPerShare: Decimal(string: "0.5")!)

        let projection = IncomeProjector.project(
            holdings: [fii, us],
            incomeGoal: Money(amount: 10_000, currency: .brl),
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )

        #expect(projection.currentMonthlyGross.amount == 125)
        #expect(projection.currentMonthlyNet.amount == Decimal(string: "117.5"))
    }
}
