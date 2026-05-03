import Testing
import Foundation
import SwiftData
import GroveDomain
import GroveServices

@MainActor
struct IncomeAggregatorTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

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

    private static func date(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private static func holding(
        in ctx: ModelContext,
        ticker: String,
        assetClass: AssetClassType,
        qty: Decimal = 10,
        firstBuy: Date = date(year: 2026, month: 1, day: 1)
    ) -> Holding {
        let h = Holding(ticker: ticker, quantity: qty, currentPrice: 100, assetClass: assetClass, status: .aportar)
        ctx.insert(h)
        let c = Contribution(date: firstBuy, amount: 1000, shares: qty, pricePerShare: 100)
        ctx.insert(c)
        c.holding = h
        return h
    }

    private static func attach(_ p: DividendPayment, to h: Holding, in ctx: ModelContext) {
        ctx.insert(p)
        p.holding = h
    }

    // MARK: - summary

    @Test func summaryEmptyHoldingsReturnsZero() {
        let s = IncomeAggregator.summary(
            holdings: [], window: .year, in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(s.paid.amount == 0)
        #expect(s.projected.amount == 0)
        #expect(s.total.amount == 0)
    }

    @Test func summaryAggregatesPaidAndProjectedAcrossHoldings() throws {
        let ctx = try Self.makeContext()
        let a = Self.holding(in: ctx, ticker: "HGLG11", assetClass: .fiis)
        let b = Self.holding(in: ctx, ticker: "BTLG11", assetClass: .fiis)
        // a paid 30, projected 20
        Self.attach(DividendPayment(exDate: Self.date(year: 2026, month: 3, day: 1),
                                    paymentDate: Self.date(year: 2026, month: 3, day: 5),
                                    amountPerShare: 3), to: a, in: ctx)
        Self.attach(DividendPayment(exDate: Self.date(year: 2026, month: 6, day: 1),
                                    paymentDate: Self.date(year: 2026, month: 6, day: 5),
                                    amountPerShare: 2), to: a, in: ctx)
        // b paid 10
        Self.attach(DividendPayment(exDate: Self.date(year: 2026, month: 2, day: 1),
                                    paymentDate: Self.date(year: 2026, month: 2, day: 5),
                                    amountPerShare: 1), to: b, in: ctx)

        let s = IncomeAggregator.summary(
            holdings: [a, b], window: .year, in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        // paid: (3+1)*10 = 40, projected: 2*10 = 20
        #expect(s.paid.amount == 40)
        #expect(s.projected.amount == 20)
        #expect(s.total.amount == 60)
    }

    @Test func summaryRespectsWindow() throws {
        let ctx = try Self.makeContext()
        let h = Self.holding(in: ctx, ticker: "HGLG11", assetClass: .fiis)
        Self.attach(DividendPayment(exDate: Self.date(year: 2026, month: 2, day: 1),
                                    paymentDate: Self.date(year: 2026, month: 2, day: 5),
                                    amountPerShare: 5), to: h, in: ctx)
        Self.attach(DividendPayment(exDate: Self.date(year: 2026, month: 4, day: 10),
                                    paymentDate: Self.date(year: 2026, month: 4, day: 15),
                                    amountPerShare: 2), to: h, in: ctx)

        let year = IncomeAggregator.summary(holdings: [h], window: .year, in: .brl,
                                            rates: Self.rates, asOf: Self.asOf, calendar: Self.utcCal)
        let month = IncomeAggregator.summary(holdings: [h], window: .month, in: .brl,
                                             rates: Self.rates, asOf: Self.asOf, calendar: Self.utcCal)
        // year: (5+2)*10 = 70
        #expect(year.paid.amount == 70)
        // month (April): only the 2/share payment, 2*10 = 20
        #expect(month.paid.amount == 20)
    }

    @Test func summaryConvertsCurrencies() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "AAPL", quantity: 10, currentPrice: 100,
                        assetClass: .usStocks, currency: .usd, status: .aportar)
        ctx.insert(h)
        let c = Contribution(date: Self.date(year: 2026, month: 1, day: 1), amount: 1000, shares: 10, pricePerShare: 100)
        ctx.insert(c); c.holding = h
        Self.attach(DividendPayment(exDate: Self.date(year: 2026, month: 3, day: 1),
                                    paymentDate: Self.date(year: 2026, month: 3, day: 5),
                                    amountPerShare: 1), to: h, in: ctx)

        let s = IncomeAggregator.summary(holdings: [h], window: .year, in: .brl,
                                         rates: Self.rates, asOf: Self.asOf, calendar: Self.utcCal)
        // 1 USD/share * 10 shares = 10 USD → 50 BRL @ 5 BRL/USD
        #expect(s.paid.amount == 50)
        #expect(s.paid.currency == .brl)
    }

    // MARK: - byClass

    @Test func byClassGroupsAndSortsByTotal() throws {
        let ctx = try Self.makeContext()
        let fii = Self.holding(in: ctx, ticker: "HGLG11", assetClass: .fiis)
        let acao = Self.holding(in: ctx, ticker: "ITUB3", assetClass: .acoesBR)
        // FIIs: paid 50
        Self.attach(DividendPayment(exDate: Self.date(year: 2026, month: 3, day: 1),
                                    paymentDate: Self.date(year: 2026, month: 3, day: 5),
                                    amountPerShare: 5), to: fii, in: ctx)
        // Ações: projected 20
        Self.attach(DividendPayment(exDate: Self.date(year: 2026, month: 6, day: 1),
                                    paymentDate: Self.date(year: 2026, month: 6, day: 5),
                                    amountPerShare: 2), to: acao, in: ctx)

        let result = IncomeAggregator.byClass(
            holdings: [fii, acao], window: .year, in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(result.count == 2)
        // FIIs come first (50 > 20)
        #expect(result[0].assetClass == .fiis)
        #expect(result[0].paid.amount == 50)
        #expect(result[0].projected.amount == 0)
        #expect(result[1].assetClass == .acoesBR)
        #expect(result[1].paid.amount == 0)
        #expect(result[1].projected.amount == 20)
    }

    @Test func byClassExcludesZeroIncomeClasses() throws {
        let ctx = try Self.makeContext()
        let fii = Self.holding(in: ctx, ticker: "HGLG11", assetClass: .fiis)
        let _ = Self.holding(in: ctx, ticker: "ITUB3", assetClass: .acoesBR) // no dividends
        Self.attach(DividendPayment(exDate: Self.date(year: 2026, month: 3, day: 1),
                                    paymentDate: Self.date(year: 2026, month: 3, day: 5),
                                    amountPerShare: 1), to: fii, in: ctx)

        let result = IncomeAggregator.byClass(
            holdings: [fii], window: .year, in: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(result.count == 1)
        #expect(result[0].assetClass == .fiis)
    }
}
