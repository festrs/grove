import Testing
import Foundation
import SwiftData
import GroveDomain

@MainActor
struct HoldingIncomeWindowTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    private static let utcCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// 2026-04-29 14:30 UTC — Wed, mid-April, mid-year.
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

    /// Helper: build a holding with a contribution at Jan 1 2026 (so all
    /// 2026 dividends are post-purchase).
    private static func makeHoldingWithContrib(in ctx: ModelContext, qty: Decimal = 10) -> Holding {
        let h = Holding(ticker: "HGLG11", quantity: qty, currentPrice: 100, assetClass: .fiis, status: .aportar)
        ctx.insert(h)
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 1
        c.timeZone = TimeZone(identifier: "UTC")
        let firstBuy = Calendar(identifier: .gregorian).date(from: c)!
        let contrib = Contribution(date: firstBuy, amount: 1000, shares: 10, pricePerShare: 100)
        ctx.insert(contrib)
        contrib.holding = h
        return h
    }

    private static func attach(_ p: DividendPayment, to h: Holding, in ctx: ModelContext) {
        ctx.insert(p)
        p.holding = h
    }

    private static func date(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    // MARK: - paidIncome

    @Test func paidIncomeIncludesPaymentInsideWindow() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHoldingWithContrib(in: ctx)
        // Paid in March 2026 (in year, NOT in current month or week)
        let mar = DividendPayment(exDate: Self.date(year: 2026, month: 3, day: 5),
                                  paymentDate: Self.date(year: 2026, month: 3, day: 10),
                                  amountPerShare: 2)
        // Paid in current month (April 2026) — also in year & week if matched
        let apr = DividendPayment(exDate: Self.date(year: 2026, month: 4, day: 10),
                                  paymentDate: Self.date(year: 2026, month: 4, day: 15),
                                  amountPerShare: 1)
        Self.attach(mar, to: h, in: ctx)
        Self.attach(apr, to: h, in: ctx)

        let yearTotal = h.paidIncome(in: .year, asOf: Self.asOf, displayCurrency: .brl,
                                     rates: Self.rates, calendar: Self.utcCal)
        // qty=10 → (2 + 1) * 10 = 30
        #expect(yearTotal.amount == 30)

        let monthTotal = h.paidIncome(in: .month, asOf: Self.asOf, displayCurrency: .brl,
                                      rates: Self.rates, calendar: Self.utcCal)
        // Only April payment
        #expect(monthTotal.amount == 10)
    }

    @Test func paidIncomeExcludesProjectedAndOutOfWindow() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHoldingWithContrib(in: ctx)
        // 2025 record — past, but paymentDate falls outside the 2026 year window.
        let outOfWindow = DividendPayment(exDate: Self.date(year: 2025, month: 12, day: 1),
                                          paymentDate: Self.date(year: 2025, month: 12, day: 5),
                                          amountPerShare: 5)
        // Past + in 2026 → counts as paid in year window.
        let paid = DividendPayment(exDate: Self.date(year: 2026, month: 2, day: 1),
                                   paymentDate: Self.date(year: 2026, month: 2, day: 5),
                                   amountPerShare: 3)
        // Future ex-date → projected, not paid.
        let proj = DividendPayment(exDate: Self.date(year: 2026, month: 6, day: 1),
                                   paymentDate: Self.date(year: 2026, month: 6, day: 5),
                                   amountPerShare: 4)
        Self.attach(outOfWindow, to: h, in: ctx)
        Self.attach(paid, to: h, in: ctx)
        Self.attach(proj, to: h, in: ctx)

        let yearTotal = h.paidIncome(in: .year, asOf: Self.asOf, displayCurrency: .brl,
                                     rates: Self.rates, calendar: Self.utcCal)
        // Only the Feb 2026 payment counts: 3 × 10 shares = 30
        #expect(yearTotal.amount == 30)
    }

    @Test func paidIncomeZeroWhenNoPayments() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHoldingWithContrib(in: ctx)
        let total = h.paidIncome(in: .year, asOf: Self.asOf, displayCurrency: .brl,
                                 rates: Self.rates, calendar: Self.utcCal)
        #expect(total.amount == 0)
    }

    // MARK: - projectedIncome

    @Test func projectedIncomeIncludesFutureExDateInsideWindow() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHoldingWithContrib(in: ctx)
        // Future, in 2026 — projected, in year window
        let p1 = DividendPayment(exDate: Self.date(year: 2026, month: 6, day: 1),
                                 paymentDate: Self.date(year: 2026, month: 6, day: 5),
                                 amountPerShare: 2)
        // Future, but in 2027 — NOT in 2026 year window
        let p2 = DividendPayment(exDate: Self.date(year: 2027, month: 1, day: 1),
                                 paymentDate: Self.date(year: 2027, month: 1, day: 5),
                                 amountPerShare: 9)
        Self.attach(p1, to: h, in: ctx)
        Self.attach(p2, to: h, in: ctx)

        let total = h.projectedIncome(in: .year, asOf: Self.asOf, displayCurrency: .brl,
                                      rates: Self.rates, calendar: Self.utcCal)
        // Only p1 in window: 2 * 10 = 20
        #expect(total.amount == 20)
    }

    @Test func projectedIncomeExcludesPaidPayments() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHoldingWithContrib(in: ctx)
        // Past ex-date → paid, NOT projected
        let paid = DividendPayment(exDate: Self.date(year: 2026, month: 3, day: 1),
                                   paymentDate: Self.date(year: 2026, month: 3, day: 5),
                                   amountPerShare: 7)
        Self.attach(paid, to: h, in: ctx)

        let total = h.projectedIncome(in: .year, asOf: Self.asOf, displayCurrency: .brl,
                                      rates: Self.rates, calendar: Self.utcCal)
        #expect(total.amount == 0)
    }
}
