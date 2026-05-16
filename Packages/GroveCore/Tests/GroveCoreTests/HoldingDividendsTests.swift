import Testing
import Foundation
import SwiftData
import GroveDomain

@MainActor
struct HoldingDividendsTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([Portfolio.self, Holding.self, UserSettings.self, DividendPayment.self, Transaction.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private static func attach(_ payment: DividendPayment, to holding: Holding, in ctx: ModelContext) {
        ctx.insert(payment)
        payment.holding = holding
    }

    // MARK: - paidDividends

    @Test func paidDividendsIncludesEveryPastDatedRecord() throws {
        let ctx = try Self.makeContext()
        // Study-mode holding (no transactions, qty = 0) — still surfaces past dividends.
        let h = Holding(ticker: "HGLG11", quantity: 0, currentPrice: 100, assetClass: .fiis, status: .estudo)
        ctx.insert(h)
        let asOf = Date(timeIntervalSince1970: 1_780_000_000)
        Self.attach(
            DividendPayment(exDate: asOf.addingTimeInterval(-86_400 * 30),
                            paymentDate: asOf.addingTimeInterval(-86_400 * 25),
                            amountPerShare: 1),
            to: h, in: ctx
        )
        Self.attach(
            DividendPayment(exDate: asOf.addingTimeInterval(86_400 * 30),
                            paymentDate: asOf.addingTimeInterval(86_400 * 35),
                            amountPerShare: 2),
            to: h, in: ctx
        )

        let paid = h.paidDividends(asOf: asOf)
        #expect(paid.count == 1, "Past-dated record surfaces regardless of transactions")
        #expect(paid.first?.amountPerShare == 1)
    }

    @Test func paidDividendsExcludesFutureExDates() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "HGLG11", quantity: 10, currentPrice: 100, assetClass: .fiis, status: .aportar)
        ctx.insert(h)
        let asOf = Date(timeIntervalSince1970: 1_780_000_000)
        Self.attach(
            DividendPayment(exDate: asOf.addingTimeInterval(86_400 * 30),
                            paymentDate: asOf.addingTimeInterval(86_400 * 35),
                            amountPerShare: 5),
            to: h, in: ctx
        )

        #expect(h.paidDividends(asOf: asOf).isEmpty)
    }

    // MARK: - projectedDividends

    @Test func projectedDividendsIncludesEveryFutureDatedRecord() throws {
        let ctx = try Self.makeContext()
        // Study-mode holding still surfaces future records — they just total to zero.
        let h = Holding(ticker: "HGLG11", quantity: 0, currentPrice: 100, assetClass: .fiis, status: .estudo)
        ctx.insert(h)
        let asOf = Date(timeIntervalSince1970: 1_780_000_000)
        let p1 = DividendPayment(exDate: asOf.addingTimeInterval(86_400 * 30),
                                 paymentDate: asOf.addingTimeInterval(86_400 * 35),
                                 amountPerShare: 3)
        let p2 = DividendPayment(exDate: asOf.addingTimeInterval(86_400 * 60),
                                 paymentDate: asOf.addingTimeInterval(86_400 * 65),
                                 amountPerShare: 4)
        Self.attach(p2, to: h, in: ctx) // out of order
        Self.attach(p1, to: h, in: ctx)

        let projected = h.projectedDividends(asOf: asOf)
        #expect(projected.count == 2)
        // Sorted ascending by paymentDate — next-up first
        #expect(projected[0].amountPerShare == 3)
        #expect(projected[1].amountPerShare == 4)
    }

    @Test func projectedDividendsExcludesPastExDates() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "HGLG11", quantity: 10, currentPrice: 100, assetClass: .fiis, status: .aportar)
        ctx.insert(h)
        let asOf = Date(timeIntervalSince1970: 1_780_000_000)
        Self.attach(
            DividendPayment(exDate: asOf.addingTimeInterval(-86_400),
                            paymentDate: asOf.addingTimeInterval(-86_400),
                            amountPerShare: 5),
            to: h, in: ctx
        )
        #expect(h.projectedDividends(asOf: asOf).isEmpty)
    }

    // MARK: - classifiedDividends

    @Test func classifiedDividendsTagsEachPaymentByDate() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "HGLG11", quantity: 10, currentPrice: 100, assetClass: .fiis, status: .aportar)
        ctx.insert(h)
        let asOf = Date(timeIntervalSince1970: 1_780_000_000)
        let past = DividendPayment(exDate: asOf.addingTimeInterval(-86_400),
                                   paymentDate: asOf.addingTimeInterval(-3600),
                                   amountPerShare: 1)
        let future = DividendPayment(exDate: asOf.addingTimeInterval(86_400),
                                     paymentDate: asOf.addingTimeInterval(86_400 * 2),
                                     amountPerShare: 2)
        Self.attach(past, to: h, in: ctx)
        Self.attach(future, to: h, in: ctx)

        let classified = h.classifiedDividends(asOf: asOf)
        #expect(classified.count == 2)
        // Sorted desc by paymentDate → future first
        #expect(classified[0].kind == .projected)
        #expect(classified[1].kind == .paid)
    }

    @Test func classifiedDividendsForStudyHoldingStillEmitsKinds() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "HGLG11", quantity: 0, currentPrice: 100, assetClass: .fiis, status: .estudo)
        ctx.insert(h)
        let asOf = Date(timeIntervalSince1970: 1_780_000_000)
        Self.attach(
            DividendPayment(exDate: asOf.addingTimeInterval(-86_400),
                            paymentDate: asOf.addingTimeInterval(-3600),
                            amountPerShare: 1),
            to: h, in: ctx
        )
        let classified = h.classifiedDividends(asOf: asOf)
        #expect(classified.count == 1)
        #expect(classified.first?.kind == .paid)
    }

    // MARK: - classifiedDividends(in: window)

    @Test func classifiedDividendsInWindowFiltersByPaymentDate() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "HGLG11", quantity: 10, currentPrice: 100, assetClass: .fiis, status: .aportar)
        ctx.insert(h)
        // 2026-05-15 12:00 UTC — sits inside May 2026 (the .month window
        // computed from this asOf).
        let asOf = Date(timeIntervalSince1970: 1_778_587_200)
        let inWindow = DividendPayment(exDate: asOf.addingTimeInterval(-86_400),
                                       paymentDate: asOf,
                                       amountPerShare: 1)
        let beforeWindow = DividendPayment(exDate: asOf.addingTimeInterval(-86_400 * 60),
                                           paymentDate: asOf.addingTimeInterval(-86_400 * 60),
                                           amountPerShare: 2)
        let afterWindow = DividendPayment(exDate: asOf.addingTimeInterval(86_400 * 60),
                                          paymentDate: asOf.addingTimeInterval(86_400 * 60),
                                          amountPerShare: 3)
        Self.attach(inWindow, to: h, in: ctx)
        Self.attach(beforeWindow, to: h, in: ctx)
        Self.attach(afterWindow, to: h, in: ctx)

        let monthRows = h.classifiedDividends(in: .month, asOf: asOf)
        #expect(monthRows.count == 1, "Only the May payment should appear in the month window")
        #expect(monthRows.first?.payment.amountPerShare == 1)

        let yearRows = h.classifiedDividends(in: .year, asOf: asOf)
        #expect(yearRows.count == 3, "All three payments fall in the same calendar year")
    }

    // MARK: - paidDividendsTotal / projectedDividendsTotal

    @Test func paidDividendsTotalScalesByCurrentQuantity() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "HGLG11", quantity: 10, currentPrice: 100, assetClass: .fiis, status: .aportar)
        ctx.insert(h)
        let asOf = Date(timeIntervalSince1970: 1_780_000_000)
        Self.attach(
            DividendPayment(exDate: asOf.addingTimeInterval(-86_400),
                            paymentDate: asOf.addingTimeInterval(-3600),
                            amountPerShare: 2),
            to: h, in: ctx
        )
        Self.attach(
            DividendPayment(exDate: asOf.addingTimeInterval(86_400),
                            paymentDate: asOf.addingTimeInterval(86_400 * 2),
                            amountPerShare: 3),
            to: h, in: ctx
        )

        let paidTotal = h.paidDividendsTotal(in: .brl, rates: Self.rates, asOf: asOf)
        #expect(paidTotal.amount == 20) // 2 × 10 shares
        let projectedTotal = h.projectedDividendsTotal(in: .brl, rates: Self.rates, asOf: asOf)
        #expect(projectedTotal.amount == 30) // 3 × 10 shares
    }

    // MARK: - ex-date == asOf boundary

    @Test func paidDividendsIncludesExDateExactlyEqualToAsOf() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "HGLG11", quantity: 10, currentPrice: 100, assetClass: .fiis, status: .aportar)
        ctx.insert(h)
        let asOf = Date(timeIntervalSince1970: 1_780_000_000)
        // exDate == asOf must count as paid (inclusive boundary).
        Self.attach(
            DividendPayment(exDate: asOf, paymentDate: asOf, amountPerShare: 7),
            to: h, in: ctx
        )

        #expect(h.paidDividends(asOf: asOf).count == 1,
                "exDate <= asOf is inclusive — equality must surface as paid")
        #expect(h.projectedDividends(asOf: asOf).isEmpty,
                "exDate > asOf is strict — equality must NOT surface as projected")
    }

    // MARK: - DividendPayment tax math

    @Test func withholdingTaxAppliesNetMultiplierCorrectly() throws {
        let ctx = try Self.makeContext()
        // 100 shares × 1 USD/share = 100 USD gross. NRA30 → multiplier 0.7,
        // so withholding = 100 × (1 - 0.7) = 30, net = 100 - 30 = 70.
        let h = Holding(ticker: "AAPL", quantity: 100, currentPrice: 100,
                        assetClass: .usStocks, currency: .usd, status: .aportar)
        ctx.insert(h)
        let p = DividendPayment(
            exDate: Date(timeIntervalSince1970: 1_780_000_000),
            paymentDate: Date(timeIntervalSince1970: 1_780_086_400),
            amountPerShare: 1,
            taxTreatment: .nra30
        )
        Self.attach(p, to: h, in: ctx)

        #expect(p.totalAmount == 100)
        #expect(p.withholdingTax == 30,
                "Sign flip on (1 - netMultiplier) would yield 170 instead of 30")
        #expect(p.netAmount == 70,
                "Sign flip on (totalAmount - withholdingTax) would yield 130 instead of 70")
    }

    @Test func studyModeHoldingContributesZeroToTotals() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "HGLG11", quantity: 0, currentPrice: 100, assetClass: .fiis, status: .estudo)
        ctx.insert(h)
        let asOf = Date(timeIntervalSince1970: 1_780_000_000)
        Self.attach(
            DividendPayment(exDate: asOf.addingTimeInterval(-86_400),
                            paymentDate: asOf.addingTimeInterval(-3600),
                            amountPerShare: 5),
            to: h, in: ctx
        )
        let paidTotal = h.paidDividendsTotal(in: .brl, rates: Self.rates, asOf: asOf)
        #expect(paidTotal.amount == 0, "qty=0 means each row totals to 0 — record stays visible in drilldown but totals are zero")
    }
}
