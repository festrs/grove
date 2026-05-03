import Testing
import Foundation
import SwiftData
import GroveDomain

@MainActor
struct HoldingDividendsTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([Portfolio.self, Holding.self, UserSettings.self, DividendPayment.self, Contribution.self])
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
        // Study-mode holding (no contributions, qty = 0) — still surfaces past dividends.
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
        #expect(paid.count == 1, "Past-dated record surfaces regardless of contributions")
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
