import Testing
import Foundation
import SwiftData
import GroveDomain

@MainActor
struct HoldingMonthlyIncomeTests {

    private static let utcCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// 2026-04-29 — frozen "now" for deterministic trailing-12m windows.
    private static let asOf: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 29
        c.hour = 12; c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([Portfolio.self, Holding.self, UserSettings.self, DividendPayment.self, Transaction.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Build a holding whose first transaction is `monthsAgo` before `asOf`,
    /// so the empirical-window annualization sees the right number of months.
    private static func makeHolding(
        in ctx: ModelContext,
        ticker: String = "ITUB3",
        qty: Decimal = 100,
        price: Decimal = 41.39,
        yield: Decimal = 0,
        firstBuyMonthsAgo: Int = 12,
        currency: Currency = .brl,
        assetClass: AssetClassType = .acoesBR
    ) -> Holding {
        let h = Holding(
            ticker: ticker,
            quantity: qty,
            currentPrice: price,
            dividendYield: yield,
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

    private static func attachMonthlyDividends(
        on holding: Holding,
        in ctx: ModelContext,
        amountPerShare: Decimal,
        months: Int
    ) {
        // empiricalAnnualGross uses strict `paymentDate > cutoff` where cutoff =
        // asOf - 12 months. Placing the oldest payment exactly at -12 months
        // would land it on the boundary and be excluded. Shift each payment
        // forward by 1 day so even the 12th lands strictly inside the window.
        for offset in 1...months {
            let monthBack = utcCal.date(byAdding: .month, value: -offset, to: asOf)!
            let payDate = utcCal.date(byAdding: .day, value: 1, to: monthBack)!
            let exDate = utcCal.date(byAdding: .day, value: -2, to: payDate)!
            let p = DividendPayment(exDate: exDate, paymentDate: payDate, amountPerShare: amountPerShare)
            ctx.insert(p)
            p.holding = holding
        }
    }

    // MARK: - TTM path

    @Test func ttmWithFullYearRecordsReturnsAnnualOverTwelve() throws {
        let ctx = try Self.makeContext()
        // 100 shares, 12 monthly payments of R$1/share → annual R$1200, monthly R$100.
        let h = Self.makeHolding(in: ctx, qty: 100, firstBuyMonthsAgo: 18)
        Self.attachMonthlyDividends(on: h, in: ctx, amountPerShare: 1, months: 12)

        let monthly = h.estimatedMonthlyIncome(asOf: Self.asOf, calendar: Self.utcCal)
        #expect(monthly == 100)
    }

    @Test func ttmWithPartialWindowAnnualizesThenDividesByTwelve() throws {
        let ctx = try Self.makeContext()
        // Held for only 3 months, with 3 monthly payments of R$1/share × 100 shares.
        // empiricalAnnualGross multiplies the partial total by 12/3 = 4 → annual 1200,
        // monthly = 100. Confirms the annualization at Holding.swift:267-269 is reused.
        let h = Self.makeHolding(in: ctx, qty: 100, firstBuyMonthsAgo: 3)
        Self.attachMonthlyDividends(on: h, in: ctx, amountPerShare: 1, months: 3)

        let monthly = h.estimatedMonthlyIncome(asOf: Self.asOf, calendar: Self.utcCal)
        #expect(monthly == 100)
    }

    // MARK: - Yield fallback

    @Test func fallsBackToYieldWhenNoRecordsAndYieldPresent() throws {
        let ctx = try Self.makeContext()
        // No dividend records, but stored dividendYield = 6.5%.
        // currentValue = 100 × 41.39 = 4139; expected monthly = 4139 × 0.065 / 12 ≈ 22.42.
        let h = Self.makeHolding(in: ctx, qty: 100, price: 41.39, yield: 6.5)
        let monthly = h.estimatedMonthlyIncome(asOf: Self.asOf, calendar: Self.utcCal)
        let expected = (Decimal(100) * Decimal(41.39) * Decimal(6.5) / 100) / 12
        #expect(monthly == expected)
    }

    @Test func returnsZeroWhenNoRecordsAndNoYield() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, qty: 100, yield: 0)
        let monthly = h.estimatedMonthlyIncome(asOf: Self.asOf, calendar: Self.utcCal)
        #expect(monthly == 0)
    }

    @Test func customHoldingWithNoRecordsReturnsZero() throws {
        let ctx = try Self.makeContext()
        let h = Holding(
            ticker: "MYHOUSE",
            quantity: 1,
            currentPrice: 250000,
            dividendYield: 0,
            assetClass: .acoesBR,
            currency: .brl,
            status: .aportar,
            isCustom: true
        )
        ctx.insert(h)
        let monthly = h.estimatedMonthlyIncome(asOf: Self.asOf, calendar: Self.utcCal)
        #expect(monthly == 0)
    }

    // MARK: - Money wrapper stays in native currency

    @Test func ttmExcludesPaymentsBeforeFirstTransaction() throws {
        // User just bought 4 months ago, but the backend (Status Invest)
        // backfilled 12 months of dividend history. Only the 4 payments
        // received WHILE OWNED should count. The 8 pre-ownership payments
        // must not flow into TTM — otherwise the annualization factor
        // (12/monthsHeld = 3) double-counts them, inflating monthly income
        // by ~3×. This was the root of the user-visible R$12k/mo bug.
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, qty: 100, firstBuyMonthsAgo: 4)
        // 12 monthly payments of R$1/share — but the holding has only existed
        // for the most recent 4 of those months.
        Self.attachMonthlyDividends(on: h, in: ctx, amountPerShare: 1, months: 12)

        let monthly = h.estimatedMonthlyIncome(asOf: Self.asOf, calendar: Self.utcCal)
        // Received-while-owned: 4 × R$1 × 100 shares = R$400 over 4 months.
        // Annualized: R$400 × (12/4) = R$1200/year. Monthly = R$100.
        // (NOT R$300 which is what the buggy formula returned.)
        #expect(monthly == 100)
    }

    @Test func netAppliesAssetClassTaxMultiplier() throws {
        let ctx = try Self.makeContext()
        // US stocks have nra30 (30% withholding → 0.70 multiplier).
        // Gross monthly = R$100. Net = 100 × 0.70 = 70.
        let h = Self.makeHolding(in: ctx, qty: 100, firstBuyMonthsAgo: 18,
                                 currency: .usd, assetClass: .usStocks)
        Self.attachMonthlyDividends(on: h, in: ctx, amountPerShare: 1, months: 12)

        let gross = h.estimatedMonthlyIncome(asOf: Self.asOf, calendar: Self.utcCal)
        let net = h.estimatedMonthlyIncomeNet(asOf: Self.asOf, calendar: Self.utcCal)
        let expectedNet = gross * h.assetClass.defaultTaxTreatment.netMultiplier
        #expect(net == expectedNet)
        #expect(net != gross, "Net must differ from gross when class has non-1.0 multiplier")
    }

    @Test func moneyWrapperReportsNativeCurrencyAmount() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, qty: 100, firstBuyMonthsAgo: 18, currency: .usd, assetClass: .usStocks)
        Self.attachMonthlyDividends(on: h, in: ctx, amountPerShare: 1, months: 12)

        // estimatedMonthlyIncomeMoney must remain in the holding's native currency.
        // FX conversion happens at the aggregate level (PortfolioRepository) via Money.sum.
        let money = h.estimatedMonthlyIncomeMoney(asOf: Self.asOf, calendar: Self.utcCal)
        #expect(money.currency == .usd)
        #expect(money.amount == 100)
    }
}
