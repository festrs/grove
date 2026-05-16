import Testing
import Foundation
import SwiftData
import GroveDomain
import GroveServices

@MainActor
struct IncomeAggregatorTrendsTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    private static let utcCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// 2026-05-09 12:00 UTC — same anchor as HoldingMonthlyIncomeTests.
    private static let asOf: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 9
        c.hour = 12; c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([Portfolio.self, Holding.self, UserSettings.self, DividendPayment.self, Transaction.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private static func makeHolding(
        in ctx: ModelContext,
        ticker: String = "ITUB3",
        qty: Decimal = 100,
        price: Decimal = 41.39,
        firstBuyMonthsAgo: Int = 24,
        currency: Currency = .brl,
        assetClass: AssetClassType = .acoesBR
    ) -> Holding {
        let h = Holding(
            ticker: ticker,
            quantity: qty,
            currentPrice: price,
            assetClass: assetClass,
            currency: currency,
            status: .aportar
        )
        ctx.insert(h)
        let firstBuy = utcCal.date(byAdding: .month, value: -firstBuyMonthsAgo, to: asOf)!
        let contrib = Transaction(date: firstBuy, amount: qty * price, shares: qty, pricePerShare: price)
        ctx.insert(contrib)
        contrib.holding = h
        return h
    }

    /// Attach `count` monthly dividends, oldest at -monthsAgoStart and shifted
    /// forward by 1 day so each lands strictly inside any > cutoff window.
    private static func attachMonthly(
        on holding: Holding,
        in ctx: ModelContext,
        amountPerShare: Decimal,
        count: Int,
        startMonthsAgo: Int = 1
    ) {
        for offset in 0..<count {
            let monthBack = utcCal.date(byAdding: .month, value: -(startMonthsAgo + offset), to: asOf)!
            let payDate = utcCal.date(byAdding: .day, value: 1, to: monthBack)!
            let exDate = utcCal.date(byAdding: .day, value: -2, to: payDate)!
            let p = DividendPayment(exDate: exDate, paymentDate: payDate, amountPerShare: amountPerShare)
            ctx.insert(p)
            p.holding = holding
        }
    }

    // MARK: - monthlyHistory

    @Test func monthlyHistoryReturnsLastNMonthBuckets() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, qty: 100, firstBuyMonthsAgo: 24)
        Self.attachMonthly(on: h, in: ctx, amountPerShare: 1, count: 12)

        let history = IncomeAggregator.monthlyHistory(
            holdings: [h], lastN: 12,
            in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )

        #expect(history.count == 12)
        // Oldest first
        let monthsAgo: [Int] = (1...12).reversed().map { $0 }
        for (i, ago) in monthsAgo.enumerated() {
            let expected = Self.utcCal.dateInterval(
                of: .month,
                for: Self.utcCal.date(byAdding: .month, value: -ago, to: Self.asOf)!
            )!.start
            #expect(history[i].monthStart == expected, "bucket \(i) expected month start \(expected)")
        }
    }

    @Test func monthlyHistoryClassifiesPaidVsProjectedRelativeToAsOf() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, qty: 100, firstBuyMonthsAgo: 24)
        // One past payment 2 months ago (paid), one future payment 2 months ahead (projected).
        let pastPay = Self.utcCal.date(byAdding: .month, value: -2, to: Self.asOf)!
        let pastEx = Self.utcCal.date(byAdding: .day, value: -2, to: pastPay)!
        let pastP = DividendPayment(exDate: pastEx, paymentDate: pastPay, amountPerShare: 1)
        ctx.insert(pastP); pastP.holding = h

        let futurePay = Self.utcCal.date(byAdding: .month, value: 2, to: Self.asOf)!
        let futureEx = Self.utcCal.date(byAdding: .day, value: -2, to: futurePay)!
        let futureP = DividendPayment(exDate: futureEx, paymentDate: futurePay, amountPerShare: 1)
        ctx.insert(futureP); futureP.holding = h

        // Window covers 4 months past + current + 3 ahead = 8 buckets.
        let history = IncomeAggregator.monthlyHistory(
            holdings: [h], lastN: 4, lookahead: 3,
            in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )

        // Find the past-month bucket: paid > 0, projected == 0.
        let pastBucket = history.first { Self.utcCal.isDate($0.monthStart, equalTo: pastPay, toGranularity: .month) }
        #expect(pastBucket?.paid.amount == 100)
        #expect(pastBucket?.projected.amount == 0)

        // Future-month bucket: paid == 0, projected > 0.
        let futureBucket = history.first { Self.utcCal.isDate($0.monthStart, equalTo: futurePay, toGranularity: .month) }
        #expect(futureBucket?.paid.amount == 0)
        #expect(futureBucket?.projected.amount == 100)
    }

    // MARK: - yoyGrowth

    @Test func yoyGrowthComputesPercentChange() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, qty: 100, firstBuyMonthsAgo: 36)
        // Prior 12mo (months -24…-13): 12 × R$1/share = R$1200
        Self.attachMonthly(on: h, in: ctx, amountPerShare: 1, count: 12, startMonthsAgo: 13)
        // Current 12mo (months -12…-1): 12 × R$1.50/share = R$1800 → +50%
        Self.attachMonthly(on: h, in: ctx, amountPerShare: 1.5, count: 12, startMonthsAgo: 1)

        let yoy = IncomeAggregator.yoyGrowth(
            holdings: [h], in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )

        #expect(yoy.currentTTM.amount == 1800)
        #expect(yoy.priorTTM.amount == 1200)
        #expect(yoy.percent == 50)
    }

    @Test func yoyGrowthReturnsNilPercentWhenPriorTTMIsZero() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, qty: 100, firstBuyMonthsAgo: 6)
        // Only current 12mo has records (6 of them); prior 12mo is empty.
        Self.attachMonthly(on: h, in: ctx, amountPerShare: 1, count: 6, startMonthsAgo: 1)

        let yoy = IncomeAggregator.yoyGrowth(
            holdings: [h], in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )

        #expect(yoy.priorTTM.amount == 0)
        #expect(yoy.percent == nil)
    }

    @Test func yoyGrowthReturnsZeroPercentWhenFlat() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, qty: 100, firstBuyMonthsAgo: 36)
        Self.attachMonthly(on: h, in: ctx, amountPerShare: 1, count: 12, startMonthsAgo: 13)
        Self.attachMonthly(on: h, in: ctx, amountPerShare: 1, count: 12, startMonthsAgo: 1)

        let yoy = IncomeAggregator.yoyGrowth(
            holdings: [h], in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(yoy.percent == 0)
    }

    // MARK: - topPayers

    @Test func topPayersRanksByTTMDescending() throws {
        let ctx = try Self.makeContext()
        let big = Self.makeHolding(in: ctx, ticker: "ITUB3", qty: 100, firstBuyMonthsAgo: 24)
        Self.attachMonthly(on: big, in: ctx, amountPerShare: 2, count: 12) // R$2400 TTM

        let med = Self.makeHolding(in: ctx, ticker: "BBAS3", qty: 100, firstBuyMonthsAgo: 24)
        Self.attachMonthly(on: med, in: ctx, amountPerShare: 1, count: 12) // R$1200 TTM

        let small = Self.makeHolding(in: ctx, ticker: "VALE3", qty: 100, firstBuyMonthsAgo: 24)
        Self.attachMonthly(on: small, in: ctx, amountPerShare: 0.5, count: 12) // R$600 TTM

        let payers = IncomeAggregator.topPayers(
            holdings: [small, big, med], limit: 5,
            in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )

        #expect(payers.count == 3)
        #expect(payers.map(\.ticker) == ["ITUB3", "BBAS3", "VALE3"])
        #expect(payers[0].ttm.amount == 2400)
        // Total = 4200; ITUB3 share = 2400/4200 ≈ 57.14%
        let expectedShare: Decimal = (Decimal(2400) / Decimal(4200)) * 100
        #expect(payers[0].share == expectedShare)
    }

    @Test func topPayersLimitClampsToHoldingsWithIncome() throws {
        let ctx = try Self.makeContext()
        let h1 = Self.makeHolding(in: ctx, ticker: "ITUB3", qty: 100, firstBuyMonthsAgo: 24)
        Self.attachMonthly(on: h1, in: ctx, amountPerShare: 1, count: 12)
        let h2 = Self.makeHolding(in: ctx, ticker: "BBAS3", qty: 100, firstBuyMonthsAgo: 24)
        Self.attachMonthly(on: h2, in: ctx, amountPerShare: 1, count: 12)

        let payers = IncomeAggregator.topPayers(
            holdings: [h1, h2], limit: 10,
            in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(payers.count == 2)
    }

    @Test func topPayersExcludesZeroIncomeHoldings() throws {
        let ctx = try Self.makeContext()
        let earner = Self.makeHolding(in: ctx, ticker: "ITUB3", qty: 100, firstBuyMonthsAgo: 24)
        Self.attachMonthly(on: earner, in: ctx, amountPerShare: 1, count: 12)
        let study = Self.makeHolding(in: ctx, ticker: "PETR4", qty: 100, firstBuyMonthsAgo: 24) // no records

        let payers = IncomeAggregator.topPayers(
            holdings: [earner, study], limit: 5,
            in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(payers.count == 1)
        #expect(payers[0].ticker == "ITUB3")
    }

    @Test func topPayersIncludesHoldingsWithContributionAfterDividends() throws {
        // Reproduces the user's report: "Top dividend payers" empty even
        // though the trend chart shows R$ paid this month.
        // Scenario: holding added via the default flow with Transaction.date
        // = today, but the backend backfilled dividend records for past
        // months. `paidIncome` (no transaction gating) shows them in the
        // trend chart, but `empiricalAnnualGross`'s `paymentDate >
        // firstContribution` filter drops every record because they all
        // predate the transaction → topPayers returns [].
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, ticker: "ITUB3", qty: 100, firstBuyMonthsAgo: 0)
        Self.attachMonthly(on: h, in: ctx, amountPerShare: 1, count: 12)

        let payers = IncomeAggregator.topPayers(
            holdings: [h], limit: 5,
            in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(!payers.isEmpty,
                "Holding has 12 months of paid records visible in the trend chart — must rank")
        #expect(payers.first?.ticker == "ITUB3")
    }

    @Test func topPayersHonorsExplicitLimit() throws {
        let ctx = try Self.makeContext()
        var holdings: [Holding] = []
        for i in 0..<7 {
            let h = Self.makeHolding(in: ctx, ticker: "T\(i)", qty: 100, firstBuyMonthsAgo: 24)
            Self.attachMonthly(on: h, in: ctx, amountPerShare: Decimal(i + 1), count: 12)
            holdings.append(h)
        }
        let payers = IncomeAggregator.topPayers(
            holdings: holdings, limit: 3,
            in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(payers.count == 3)
        #expect(payers.map(\.ticker) == ["T6", "T5", "T4"])
    }

    // MARK: - concentration

    @Test func concentrationTopNPlusRest() throws {
        let ctx = try Self.makeContext()
        var holdings: [Holding] = []
        for i in 0..<5 {
            let h = Self.makeHolding(in: ctx, ticker: "T\(i)", qty: 100, firstBuyMonthsAgo: 24)
            // TTMs: 1200, 2400, 3600, 4800, 6000  → total 18000
            Self.attachMonthly(on: h, in: ctx, amountPerShare: Decimal(i + 1), count: 12)
            holdings.append(h)
        }
        let conc = IncomeAggregator.concentration(
            holdings: holdings, topN: 3,
            in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        // Top 3 = T4 (6000) + T3 (4800) + T2 (3600) = 14400 / 18000 = 80%
        #expect(conc.topShare == 80)
        // Segments: 3 top + 1 "Rest" = 4 segments
        #expect(conc.segments.count == 4)
        // Sum of all segments = 100
        let sum = conc.segments.map(\.share).reduce(Decimal.zero, +)
        #expect(sum == 100)
        // Rest segment must be present and labelled "Rest"
        #expect(conc.segments.last?.label == "Rest")
    }

    @Test func concentrationOmitsRestWhenHoldingsLeqTopN() throws {
        let ctx = try Self.makeContext()
        let h1 = Self.makeHolding(in: ctx, ticker: "ITUB3", qty: 100, firstBuyMonthsAgo: 24)
        Self.attachMonthly(on: h1, in: ctx, amountPerShare: 1, count: 12)
        let h2 = Self.makeHolding(in: ctx, ticker: "BBAS3", qty: 100, firstBuyMonthsAgo: 24)
        Self.attachMonthly(on: h2, in: ctx, amountPerShare: 1, count: 12)

        let conc = IncomeAggregator.concentration(
            holdings: [h1, h2], topN: 5,
            in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        // 2 holdings, both equal — topN=5 covers everything → no Rest.
        #expect(conc.segments.count == 2)
        #expect(conc.segments.allSatisfy { $0.label != "Rest" })
        #expect(conc.topShare == 100)
    }

    @Test func concentrationReturnsEmptyWhenNoIncome() throws {
        let ctx = try Self.makeContext()
        _ = Self.makeHolding(in: ctx, ticker: "ITUB3", qty: 100, firstBuyMonthsAgo: 24)
        // No dividends attached.

        let conc = IncomeAggregator.concentration(
            holdings: [], topN: 3,
            in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(conc.segments.isEmpty)
        #expect(conc.topShare == 0)
    }
}
