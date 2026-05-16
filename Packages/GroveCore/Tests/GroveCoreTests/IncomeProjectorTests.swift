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
        let schema = Schema([Portfolio.self, Holding.self, UserSettings.self, DividendPayment.self, Transaction.self])
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
        let contrib = Transaction(date: janFirst(), amount: 1, shares: qty, pricePerShare: price)
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

    @Test func progressPercentTracksAnnualizedRunRate() throws {
        // Holding paid R$100 in April; held since Jan 1 (3 months by `.month`
        // calendar diff) → empiricalAnnualGross = 100 × (12/3) = 400 →
        // annualizedMonthlyNet = 400/12 = 33.33… → 33.33 / 1000 × 100 = 3.33%.
        // Mutation flipping to `currentMonthlyNet/goal` would produce 10%.
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 12,
                                 assetClass: .fiis, aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h], incomeGoal: Self.brlGoal,
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        let expected = Decimal(400) / Decimal(12) / Decimal(1000) * 100
        #expect(projection.progressPercent == expected)
    }

    @Test func paidThisMonthIsRealPaidOnly() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 12,
                                 assetClass: .fiis, aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h], incomeGoal: Self.brlGoal,
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(projection.paidThisMonthNet.amount == 100, "FII paid R$100 in April, exempt")
    }

    @Test func annualizedMonthlyAppliesTaxBreakdown() throws {
        // US stock paid 1 USD/share × 100 shares in April = 100 USD raw.
        // Held 3 months → annualize ×4 → 400 USD/yr → 33.33 USD/mo gross →
        // 166.66 BRL/mo gross. NRA30 tax → 116.66 BRL/mo net.
        // Decimal precision: the per-holding /12 then ×0.7 path produces a
        // trailing-digit artifact vs (1400/12), so compare with tolerance.
        let ctx = try Self.makeContext()
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
        let expected = Decimal(1400) / 12
        let diff = projection.annualizedMonthlyNet.amount - expected
        #expect(abs(diff) < Decimal(string: "0.0001")!,
                "annualizedMonthlyNet \(projection.annualizedMonthlyNet.amount) ≠ \(expected)")
    }

    @Test func goalSimUsesDYFromHoldings() throws {
        // Real records: 100 BRL paid in April. Held 3 months → annualizes to
        // 400 BRL/yr → seed annualizedMonthlyNet = 33.33 BRL/mo (FII exempt).
        // Sim: total value = 10000 BRL; bestAnnualGross = max(empirical=400,
        // stored=10000×12%=1200) = 1200 → avgDY=12% → monthlyYield=0.01.
        // Per-iter += 5000 × 0.01 × 1.0 = 50. Need (1000 - 33.33)/50 → 20 iter.
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 12,
                                 assetClass: .fiis, aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h], incomeGoal: Self.brlGoal,
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )

        #expect(projection.estimatedMonthsToGoal == 20,
                "Loop must run when run-rate < goal — mutation flipping < to > would skip and return nil")
        #expect(projection.estimatedYearsToGoal == Decimal(20) / 12)
    }

    @Test func goalReachedShowsZeroMonths() throws {
        // 12 monthly payments of R$1/share × 1000 shares so the empirical
        // annual gross sits well above the R$500 goal (annualizedMonthlyNet
        // ≈ R$1 091/mo). Goal reached → progress capped at 100, sim returns 0.
        let ctx = try Self.makeContext()
        let recs: [(payment: Date, ex: Date, perShare: Decimal)] = [
            (Self.calDate(2025, 5, 15), Self.calDate(2025, 5, 10), 1),
            (Self.calDate(2025, 6, 15), Self.calDate(2025, 6, 10), 1),
            (Self.calDate(2025, 7, 15), Self.calDate(2025, 7, 10), 1),
            (Self.calDate(2025, 8, 15), Self.calDate(2025, 8, 10), 1),
            (Self.calDate(2025, 9, 15), Self.calDate(2025, 9, 10), 1),
            (Self.calDate(2025, 10, 15), Self.calDate(2025, 10, 10), 1),
            (Self.calDate(2025, 11, 15), Self.calDate(2025, 11, 10), 1),
            (Self.calDate(2025, 12, 15), Self.calDate(2025, 12, 10), 1),
            (Self.calDate(2026, 1, 15), Self.calDate(2026, 1, 10), 1),
            (Self.calDate(2026, 2, 15), Self.calDate(2026, 2, 10), 1),
            (Self.calDate(2026, 3, 15), Self.calDate(2026, 3, 10), 1),
            (Self.calDate(2026, 4, 15), Self.calDate(2026, 4, 10), 1)
        ]
        let h = Self.seedHoldingWithHistory(
            in: ctx, ticker: "FII1", qty: 1000, price: 100, dy: 12,
            assetClass: .fiis,
            firstContribDate: Self.calDate(2025, 5, 1),
            records: recs
        )
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

    @Test func goalSimAppliesAvgNetMultiplier() throws {
        // Pure US-stocks portfolio so avgNetMultiplier ≠ 1.0 (NRA30 → 0.7).
        // 100 shares × 100 USD → 10,000 USD = 50,000 BRL portfolio value.
        // April dividend: 100 USD raw, held 3 mo → empiricalAnnualGross
        // = 100 × 4 = 400 USD = 2000 BRL/yr → 1400 BRL/yr net (NRA30) →
        // annualizedMonthlyNet = 116.66 BRL/mo (sim seed).
        // bestAnnualGross = max(2000 BRL empirical, 12% × 50000 = 6000 BRL
        // stored) = 6000 → avgDY = 12% → monthlyYield = 0.01.
        // avgNetMultiplier from current month: 500 gross / 350 net = 0.7.
        // Per-iter += 5000 × 0.01 × 0.7 = 35.
        // Need (1000 - 116.66) / 35 ≈ 25.24 → 26 months.
        // Dropping the multiplier yields 50/iter → 18 months instead.
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, ticker: "AAPL", qty: 100, price: 100, dy: 12,
                                 assetClass: .usStocks, currency: .usd,
                                 aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h], incomeGoal: Self.brlGoal,
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )

        #expect(projection.estimatedMonthsToGoal == 26,
                "Sim must scale contribution growth by avgNetMultiplier — dropping it gives 18")
    }

    // MARK: - Mixed Portfolio

    // MARK: - Target Year

    @Test func targetYearReportsMonthsRemaining() throws {
        // asOf = 2026-04-29; target = 2030-01-01 → 44 months.
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 12,
                                 assetClass: .fiis, aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h], incomeGoal: Self.brlGoal,
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            targetYear: 2030,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(projection.monthsRemainingToTargetYear == 44)
    }

    @Test func onTrackTrueWhenEstimateBeatsTarget() throws {
        // estimatedMonths = 18 (from goalSimUsesDYFromHoldings) vs 44 months remaining → on track.
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 12,
                                 assetClass: .fiis, aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h], incomeGoal: Self.brlGoal,
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            targetYear: 2030,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(projection.onTrackForTargetYear == true)
    }

    @Test func onTrackFalseWhenEstimateExceedsTarget() throws {
        // 18 months estimated vs target 2026-12-31 → only 8 months remain → off track.
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 12,
                                 assetClass: .fiis, aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h], incomeGoal: Self.brlGoal,
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            targetYear: 2027,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(projection.monthsRemainingToTargetYear == 8)
        #expect(projection.onTrackForTargetYear == false)
    }

    @Test func targetYearNilWhenNotProvided() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 12,
                                 assetClass: .fiis, aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h], incomeGoal: Self.brlGoal,
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(projection.monthsRemainingToTargetYear == nil)
        #expect(projection.onTrackForTargetYear == nil)
    }

    // MARK: - OnTrackStatus

    private static func projection(
        targetFIYear: Int? = nil,
        monthsRemaining: Int? = nil,
        estMonths: Int? = nil,
        onTrack: Bool? = nil,
        progress: Decimal = 50
    ) -> IncomeProjection {
        IncomeProjection(
            currentMonthlyNet: Money(amount: 1, currency: .brl),
            currentMonthlyGross: Money(amount: 1, currency: .brl),
            paidThisMonthNet: Money(amount: 1, currency: .brl),
            annualizedMonthlyNet: Money(amount: 1, currency: .brl),
            goalMonthly: Money(amount: 100, currency: .brl),
            progressPercent: progress,
            estimatedMonthsToGoal: estMonths,
            estimatedYearsToGoal: estMonths.map { Decimal($0) / 12 },
            targetFIYear: targetFIYear,
            monthsRemainingToTargetYear: monthsRemaining,
            onTrackForTargetYear: onTrack
        )
    }

    @Test func statusHiddenWithoutTargetYear() {
        #expect(Self.projection().targetYearStatus == .hidden)
    }

    @Test func statusHiddenWhenGoalReached() {
        let p = Self.projection(targetFIYear: 2046, monthsRemaining: 240, estMonths: 24, onTrack: true, progress: 100)
        #expect(p.targetYearStatus == .hidden)
    }

    @Test func statusOnTrack() {
        let p = Self.projection(targetFIYear: 2046, monthsRemaining: 240, estMonths: 24, onTrack: true)
        #expect(p.targetYearStatus == .onTrack(year: 2046))
    }

    @Test func statusTightUnder36MonthsGap() {
        // gap = 60 - 36 = 24 months → 2 years short → tight
        let p = Self.projection(targetFIYear: 2029, monthsRemaining: 36, estMonths: 60, onTrack: false)
        #expect(p.targetYearStatus == .tight(year: 2029, yearsShort: 2))
    }

    @Test func statusFarOver36MonthsGap() {
        // gap = 240 - 60 = 180 months → 15 years short → far
        let p = Self.projection(targetFIYear: 2030, monthsRemaining: 60, estMonths: 240, onTrack: false)
        #expect(p.targetYearStatus == .far(year: 2030, yearsShort: 15))
    }

    @Test func statusNeedTransactionWhenSimCappedOut() {
        // estimatedMonthsToGoal = nil → sim hit the 600-month cap
        let p = Self.projection(targetFIYear: 2046, monthsRemaining: 240, estMonths: nil, onTrack: nil)
        #expect(p.targetYearStatus == .needTransaction(year: 2046))
    }

    @Test func statusTightAtExactly36MonthGapBoundary() {
        // gap = 72 - 36 = 36 → exactly the boundary, still tight (≤ 36)
        let p = Self.projection(targetFIYear: 2029, monthsRemaining: 36, estMonths: 72, onTrack: false)
        #expect(p.targetYearStatus == .tight(year: 2029, yearsShort: 3))
    }

    @Test func statusYearsShortRoundsUpFromAnyRemainder() {
        // gap = 49 - 36 = 13 months → ceil(13/12) = 2 years short
        let p = Self.projection(targetFIYear: 2029, monthsRemaining: 36, estMonths: 49, onTrack: false)
        #expect(p.targetYearStatus == .tight(year: 2029, yearsShort: 2))
    }

    @Test func targetYearInPastClampsToZero() throws {
        let ctx = try Self.makeContext()
        let h = Self.makeHolding(in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 12,
                                 assetClass: .fiis, aprilDividendPerShare: 1)
        let projection = IncomeProjector.project(
            holdings: [h], incomeGoal: Self.brlGoal,
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            targetYear: 2020,
            asOf: Self.asOf, calendar: Self.utcCal
        )
        #expect(projection.monthsRemainingToTargetYear == 0)
        #expect(projection.onTrackForTargetYear == false,
                "Estimated months (>0) cannot fit in 0 remaining months → off track.")
    }

    // MARK: - Empirical-yield rolling window

    /// Seed a holding owned since `firstContribDate` with an arbitrary set
    /// of `DividendPayment` records. Caller picks portfolio currency + qty.
    private static func seedHoldingWithHistory(
        in ctx: ModelContext,
        ticker: String,
        qty: Decimal,
        price: Decimal,
        dy: Decimal,
        assetClass: AssetClassType,
        firstContribDate: Date,
        records: [(payment: Date, ex: Date, perShare: Decimal)]
    ) -> Holding {
        let h = Holding(ticker: ticker, quantity: qty, currentPrice: price,
                        dividendYield: dy, assetClass: assetClass,
                        status: .aportar, targetPercent: 100)
        ctx.insert(h)
        let contrib = Transaction(date: firstContribDate, amount: 1, shares: qty, pricePerShare: price)
        ctx.insert(contrib); contrib.holding = h
        for r in records {
            let p = DividendPayment(exDate: r.ex, paymentDate: r.payment, amountPerShare: r.perShare)
            ctx.insert(p); p.holding = h
        }
        return h
    }

    private static func calDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 12
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    @Test func empiricalYieldKicksInWhenStoredDYIsZero() throws {
        // Stored DY = 0 (so storedAnnualGross = 0).
        // 12 monthly payments of R$1/share × 100 shares = R$1200/yr empirical.
        // Portfolio value = 10 000 → 12% empirical DY → 1% monthly yield.
        // Without the patch, avgDY collapses to the 6% default fallback,
        // taking ~40 months. With empirical (12%), tighter than that.
        let ctx = try Self.makeContext()
        let payments: [(Date, Date, Decimal)] = (1...12).map { i in
            (Self.calDate(2025, i, 15), Self.calDate(2025, i, 10), Decimal(1))
        }
        let h = Self.seedHoldingWithHistory(
            in: ctx, ticker: "FII1", qty: 100, price: 100, dy: 0,
            assetClass: .fiis,
            firstContribDate: Self.calDate(2025, 1, 1),
            records: payments
        )
        let asOf = Self.calDate(2026, 1, 5)
        let projection = IncomeProjector.project(
            holdings: [h],
            incomeGoal: Money(amount: 1_000, currency: .brl),
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: asOf, calendar: Self.utcCal
        )
        #expect(projection.estimatedMonthsToGoal != nil)
        #expect((projection.estimatedMonthsToGoal ?? 999) < 40,
                "Empirical 12% yield must beat the 6% default fallback (~40 months).")
    }

    @Test func storedYieldKicksInWhenNoRecordsYet() throws {
        // No records — fresh holding. Stored DY = 12% must drive the sim.
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "FII1", quantity: 100, currentPrice: 100,
                        dividendYield: 12, assetClass: .fiis,
                        status: .aportar, targetPercent: 100)
        ctx.insert(h)
        let contrib = Transaction(date: Self.calDate(2025, 12, 1), amount: 1, shares: 100, pricePerShare: 100)
        ctx.insert(contrib); contrib.holding = h
        let asOf = Self.calDate(2026, 1, 5)
        let projection = IncomeProjector.project(
            holdings: [h],
            incomeGoal: Money(amount: 1_000, currency: .brl),
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: asOf, calendar: Self.utcCal
        )
        #expect(projection.estimatedMonthsToGoal != nil)
    }

    @Test func empiricalAnnualGrossExcludesPaymentExactlyAtCutoff() throws {
        // The 12-month window is `(cutoff, asOf]` — strictly greater than
        // cutoff. A payment on the exact boundary day must be excluded.
        // Mutation `> cutoff` → `>= cutoff` would include it and double the total.
        let ctx = try Self.makeContext()
        let asOf = Self.calDate(2026, 1, 5)
        let cutoff = Self.calDate(2025, 1, 5)
        let h = Self.seedHoldingWithHistory(
            in: ctx, ticker: "AB", qty: 100, price: 100, dy: 0,
            assetClass: .fiis,
            firstContribDate: Self.calDate(2024, 1, 1),
            records: [
                (cutoff, Self.calDate(2025, 1, 1), 1),                  // exactly on cutoff: excluded
                (Self.calDate(2025, 6, 15), Self.calDate(2025, 6, 1), 1) // inside window: included
            ]
        )
        let result = h.empiricalAnnualGross(
            asOf: asOf, displayCurrency: .brl, rates: Self.rates, calendar: Self.utcCal
        )
        #expect(result.amount == 100,
                "Boundary record at cutoff must be excluded; >= mutation would give 200.")
    }

    @Test func empiricalAnnualGrossExcludesPaymentsOlderThan12Months() throws {
        let ctx = try Self.makeContext()
        let h = Self.seedHoldingWithHistory(
            in: ctx, ticker: "AB", qty: 100, price: 100, dy: 0,
            assetClass: .fiis,
            firstContribDate: Self.calDate(2024, 1, 1),
            records: [
                (Self.calDate(2024, 11, 15), Self.calDate(2024, 11, 10), 1),
                (Self.calDate(2025, 2, 15), Self.calDate(2025, 2, 10), 1),
            ]
        )
        let asOf = Self.calDate(2026, 1, 5)
        let result = h.empiricalAnnualGross(
            asOf: asOf, displayCurrency: .brl, rates: Self.rates, calendar: Self.utcCal
        )
        #expect(result.amount == 100,
                "Records older than 12 months from asOf must be excluded.")
    }

    @Test func empiricalAnnualGrossScalesByCurrentQuantity() throws {
        let ctx = try Self.makeContext()
        let h = Self.seedHoldingWithHistory(
            in: ctx, ticker: "AB", qty: 100, price: 100, dy: 0,
            assetClass: .fiis,
            firstContribDate: Self.calDate(2024, 1, 1),
            records: [(Self.calDate(2025, 6, 15), Self.calDate(2025, 6, 10), 1)]
        )
        let asOf = Self.calDate(2026, 1, 5)
        let result = h.empiricalAnnualGross(
            asOf: asOf, displayCurrency: .brl, rates: Self.rates, calendar: Self.utcCal
        )
        #expect(result.amount == 100)
    }

    @Test func empiricalAnnualGrossAnnualizesPartialWindow() throws {
        let ctx = try Self.makeContext()
        // Held 3 months with 3 monthly R$1/share records → R$300 raw, ×4 → R$1200/yr.
        let h = Self.seedHoldingWithHistory(
            in: ctx, ticker: "AB", qty: 100, price: 100, dy: 0,
            assetClass: .fiis,
            firstContribDate: Self.calDate(2025, 10, 1),
            records: [
                (Self.calDate(2025, 11, 15), Self.calDate(2025, 11, 10), 1),
                (Self.calDate(2025, 12, 15), Self.calDate(2025, 12, 10), 1),
                (Self.calDate(2026, 1, 5), Self.calDate(2025, 12, 28), 1),
            ]
        )
        let asOf = Self.calDate(2026, 1, 6)
        let result = h.empiricalAnnualGross(
            asOf: asOf, displayCurrency: .brl, rates: Self.rates, calendar: Self.utcCal
        )
        #expect(result.amount == 1_200,
                "3 months of R$300 must annualize to R$1200 (drop scaling -> 300).")
    }

    @Test func empiricalAnnualGrossUsesTrailingWindowWhenNoTransactions() throws {
        // Imported holding: dividend records exist but no Transaction row
        // was seeded. Earlier behaviour defaulted firstTransaction to asOf,
        // collapsing the window to empty and silently returning 0 — which is
        // why "Top dividend payers" and "Income concentration" were empty
        // for users with real records but no contribution history.
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "ITUB4", quantity: 100, currentPrice: 30,
                        dividendYield: 0, assetClass: .acoesBR,
                        status: .aportar, targetPercent: 100)
        ctx.insert(h)
        let payment = DividendPayment(
            exDate: Self.calDate(2025, 8, 1),
            paymentDate: Self.calDate(2025, 8, 15),
            amountPerShare: 1
        )
        ctx.insert(payment); payment.holding = h
        let asOf = Self.calDate(2026, 1, 5)
        let result = h.empiricalAnnualGross(
            asOf: asOf, displayCurrency: .brl, rates: Self.rates, calendar: Self.utcCal
        )
        #expect(result.amount == 100,
                "1 record × R$1 × 100 shares over a full 12mo fallback window = R$100/yr")
    }

    @Test func empiricalAnnualGrossReturnsZeroWithNoQuantity() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "X", quantity: 0, currentPrice: 100,
                        dividendYield: 0, assetClass: .fiis,
                        status: .estudo, targetPercent: 0)
        ctx.insert(h)
        let result = h.empiricalAnnualGross(
            asOf: Self.calDate(2026, 1, 5),
            displayCurrency: .brl, rates: Self.rates, calendar: Self.utcCal
        )
        #expect(result.amount == 0)
    }

    @Test func portfolioMaxOfStoredAndEmpiricalPrefersHigher() throws {
        // Records span 2025/02 → 2026/01 so the latest one falls in the
        // asOf calendar month — totalGross > 0 → avgNetMultiplier == 1.0
        // for FIIs (exempt). Sim starts at totalNet = R$100/mo (the Jan payment).
        // Empirical = R$1200/yr. Stored DY = 24% → R$2400/yr.
        // max → avgDY 24% → 0.02/mo → +R$100/iter → (1000-100)/100 = 9 iter.
        // min flip → avgDY 12% → 0.01/mo → +R$50/iter → 900/50 = 18 iter.
        let ctx = try Self.makeContext()
        // Build 12 monthly records ending in Jan 2026 so the latest one is in
        // the current calendar month at asOf.
        let recs: [(Date, Date, Decimal)] = (0..<12).map { offset in
            let y = offset >= 11 ? 2026 : 2025
            let m = offset >= 11 ? 1 : (offset + 2)
            return (Self.calDate(y, m, 15), Self.calDate(y, m, 3), 1)
        }
        let h = Self.seedHoldingWithHistory(
            in: ctx, ticker: "AB", qty: 100, price: 100, dy: 24,
            assetClass: .fiis,
            firstContribDate: Self.calDate(2025, 1, 1),
            records: recs
        )
        let asOf = Self.calDate(2026, 1, 20)
        let projection = IncomeProjector.project(
            holdings: [h],
            incomeGoal: Money(amount: 1_000, currency: .brl),
            monthlyContribution: Self.brlContribution,
            displayCurrency: .brl, rates: Self.rates,
            asOf: asOf, calendar: Self.utcCal
        )
        #expect(projection.estimatedMonthsToGoal == 9,
                "max() must pick stored (R$2400) → 9 months; min() flip would give 18.")
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
