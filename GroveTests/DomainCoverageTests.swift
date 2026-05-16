import Testing
import Foundation
import SwiftData
import GroveDomain

/// Coverage-bumping suite for `GroveDomain` types whose behaviour is otherwise
/// only exercised through service-layer SPM tests (which `just coverage`
/// doesn't measure since it scopes to the iOS GroveTests bundle). Each test
/// targets a distinct uncovered branch — see comments per test.

@MainActor
struct DomainCoverageTests {

    // MARK: - IncomeWindow.dateRange

    private static let utcCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    private static let asOf: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 14
        c.hour = 13; c.minute = 30
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    @Test func incomeWindowDayRangeAnchorsToStartOfDay() {
        let range = IncomeWindow.day.dateRange(asOf: Self.asOf, calendar: Self.utcCal)
        let comps = Self.utcCal.dateComponents([.hour, .minute], from: range.lowerBound)
        #expect(comps.hour == 0 && comps.minute == 0)
        #expect(range.upperBound > range.lowerBound)
    }

    @Test func incomeWindowWeekRangeSpansSevenDays() {
        let range = IncomeWindow.week.dateRange(asOf: Self.asOf, calendar: Self.utcCal)
        let span = range.upperBound.timeIntervalSince(range.lowerBound)
        // 7 days minus 1 second (closed range derived from a half-open interval)
        #expect(span > 6 * 86_400 && span < 7 * 86_400)
    }

    @Test func incomeWindowMonthRangeSpansCurrentMonth() {
        let range = IncomeWindow.month.dateRange(asOf: Self.asOf, calendar: Self.utcCal)
        let startComps = Self.utcCal.dateComponents([.year, .month, .day], from: range.lowerBound)
        #expect(startComps.year == 2026 && startComps.month == 5 && startComps.day == 1)
    }

    @Test func incomeWindowYearRangeSpansCurrentYear() {
        let range = IncomeWindow.year.dateRange(asOf: Self.asOf, calendar: Self.utcCal)
        let startComps = Self.utcCal.dateComponents([.year, .month, .day], from: range.lowerBound)
        #expect(startComps.year == 2026 && startComps.month == 1 && startComps.day == 1)
    }

    @Test func incomeWindowCustomReturnsForwardRange() {
        let start = Self.asOf
        let end = Self.utcCal.date(byAdding: .day, value: 5, to: start)!
        let range = IncomeWindow.custom(start: start, end: end).dateRange(asOf: Self.asOf, calendar: Self.utcCal)
        #expect(range.lowerBound == start && range.upperBound == end)
    }

    @Test func incomeWindowCustomNormalisesReversedRange() {
        // When start > end, the helper must swap them — otherwise the
        // ClosedRange initialiser traps. This protects callers that pass
        // dates from arbitrary user input.
        let later = Self.asOf
        let earlier = Self.utcCal.date(byAdding: .day, value: -5, to: later)!
        let range = IncomeWindow.custom(start: later, end: earlier).dateRange(asOf: Self.asOf, calendar: Self.utcCal)
        #expect(range.lowerBound == earlier && range.upperBound == later)
    }

    // MARK: - DividendPayment derived properties

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([Portfolio.self, Holding.self, UserSettings.self, DividendPayment.self, Transaction.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test func dividendNetAmountAppliesTaxTreatmentMultiplier() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "AAPL", quantity: 100, currentPrice: 100,
                        assetClass: .usStocks, currency: .usd, status: .aportar, targetPercent: 0)
        ctx.insert(h)
        let p = DividendPayment(exDate: Self.asOf, paymentDate: Self.asOf,
                                amountPerShare: 1, taxTreatment: .nra30)
        ctx.insert(p); p.holding = h

        #expect(p.totalAmount == 100)
        #expect(p.withholdingTax == 30) // 30% NRA
        #expect(p.netAmount == 70)
        #expect(p.totalAmountMoney.currency == .usd)
        #expect(p.netAmountMoney.amount == 70)
        #expect(p.withholdingTaxMoney.amount == 30)
        #expect(p.amountPerShareMoney.amount == 1)
        #expect(p.isInformational == false)
    }

    @Test func dividendInformationalWhenHoldingHasNoShares() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "STUDY", quantity: 0, currentPrice: 50,
                        assetClass: .acoesBR, currency: .brl, status: .estudo, targetPercent: 0)
        ctx.insert(h)
        let p = DividendPayment(exDate: Self.asOf, paymentDate: Self.asOf, amountPerShare: 1)
        ctx.insert(p); p.holding = h

        #expect(p.totalAmount == 0)
        #expect(p.isInformational == true)
    }

    @Test func dividendDefaultsToBRLWhenHoldingDetached() {
        // No holding linked → resolvedCurrency falls back to .brl. This is the
        // safety net the SwiftData editor relies on when a record is held in
        // memory before persisting.
        let p = DividendPayment(exDate: Self.asOf, paymentDate: Self.asOf, amountPerShare: 1)
        #expect(p.totalAmountMoney.currency == .brl)
        #expect(p.netAmountMoney.currency == .brl)
    }

    @Test func dividendKindStringRawValuesAreStable() {
        // Persisted into views via `.kind.rawValue` in some places — keep the
        // string contract pinned so storage migrations don't drift.
        #expect(DividendKind.paid.rawValue == "paid")
        #expect(DividendKind.projected.rawValue == "projected")
    }

    // MARK: - ExchangeRates

    @Test func identityRatesReturnsOneWhenSourceMatchesTarget() {
        let r = IdentityRates()
        #expect(r.rate(from: .brl, to: .brl) == 1)
        #expect(r.rate(from: .usd, to: .usd) == 1)
    }

    @Test func staticRatesUsdBrlAndInverse() {
        let r = StaticRates(brlPerUsd: 5)
        #expect(r.rate(from: .usd, to: .brl) == 5)
        #expect(r.rate(from: .brl, to: .usd) == Decimal(1) / 5)
        #expect(r.rate(from: .brl, to: .brl) == 1)
    }

    // MARK: - Decimal+Currency formatting

    @Test func formattedCompactScalesByMagnitude() {
        // The compact formatter has three branches: < 1k (no suffix),
        // ≥1k (k suffix), ≥1M (M suffix). All three must run.
        let small = Decimal(123).formattedCompact()
        let medium = Decimal(45_678).formattedCompact()
        let large = Decimal(2_500_000).formattedCompact()
        #expect(small == "123")
        #expect(medium.hasSuffix("k"))
        #expect(large.hasSuffix("M"))
    }

    @Test func formattedCompactHandlesNegativeMagnitudes() {
        // The threshold uses abs(); a -R$1.2M loss still gets the M suffix.
        let neg = Decimal(-1_500_000).formattedCompact()
        #expect(neg.contains("-") && neg.hasSuffix("M"))
    }

    @Test func formattedAsBrlIncludesSymbol() {
        let s = Decimal(1234.56).formatted(as: .brl)
        #expect(s.contains("R$"))
    }

    @Test func formattedPercentWithCustomDecimals() {
        let s = Decimal(27.5).formattedPercent(decimals: 2)
        #expect(s.contains("27") && s.contains("%"))
    }

    // MARK: - Money — extra branches not hit by MoneyTests

    @Test func decimalTimesMoneyMatchesMoneyTimesDecimal() {
        // Reverse-multiply overload (Decimal × Money) — the tests cover the
        // forward direction, this exercises the other arity.
        let m = Money(amount: 50, currency: .brl)
        let result = Decimal(3) * m
        #expect(result.amount == 150 && result.currency == .brl)
    }

    @Test func moneyComparableLessThanWithSameCurrency() {
        let a = Money(amount: 10, currency: .usd)
        let b = Money(amount: 20, currency: .usd)
        #expect(a < b)
        #expect(!(b < a))
    }

    @Test func moneySumOfEmptySequenceReturnsZero() {
        // The reducer seeds at .zero; an empty array must therefore yield
        // zero in the target currency, not crash.
        let empty: [Money] = []
        let total = empty.sum(in: .brl, using: StaticRates(brlPerUsd: 5))
        #expect(total == .zero(in: .brl))
    }

    @Test func moneyDtoRoundtripPreservesAmountAndCurrency() {
        let m = Money(amount: Decimal(string: "987.65")!, currency: .brl)
        let dto = m.dto
        #expect(dto.currency == "BRL")
        let parsed = Money(dto: dto)
        #expect(parsed?.amount == m.amount && parsed?.currency == .brl)
    }

    // MARK: - Holding helpers

    @Test func holdingCurrentPercentReturnsZeroWhenPortfolioEmpty() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "ITUB3", quantity: 100, currentPrice: 30,
                        assetClass: .acoesBR, currency: .brl, status: .aportar, targetPercent: 50)
        ctx.insert(h)
        let pct = h.currentPercent(of: .zero(in: .brl), in: .brl, rates: StaticRates(brlPerUsd: 5))
        #expect(pct == 0)
    }

    @Test func holdingAllocationGapPositiveWhenUnderTarget() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "ITUB3", quantity: 100, currentPrice: 30,
                        assetClass: .acoesBR, currency: .brl, status: .aportar, targetPercent: 50)
        ctx.insert(h)
        // total = R$30k, holding = R$3k → 10%, gap = 50 - 10 = 40
        let gap = h.allocationGap(totalValue: Money(amount: 30_000, currency: .brl),
                                  in: .brl, rates: StaticRates(brlPerUsd: 5))
        #expect(gap == 40)
    }

    @Test func holdingGainLossPercentZeroWhenNoCost() throws {
        // Edge case: a holding bought at 0 cost (study mode placeholder) must
        // not divide by zero — gainLossPercent returns 0.
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "X", quantity: 0, currentPrice: 0,
                        assetClass: .acoesBR, currency: .brl, status: .estudo, targetPercent: 0)
        ctx.insert(h)
        #expect(h.gainLossPercent == 0)
    }

    @Test func holdingHasPositionMatchesQuantity() throws {
        let ctx = try Self.makeContext()
        let positioned = Holding(ticker: "A", quantity: 10, currentPrice: 1,
                                 assetClass: .acoesBR, currency: .brl, status: .aportar, targetPercent: 0)
        ctx.insert(positioned)
        let zero = Holding(ticker: "B", quantity: 0, currentPrice: 1,
                           assetClass: .acoesBR, currency: .brl, status: .estudo, targetPercent: 0)
        ctx.insert(zero)
        #expect(positioned.hasPosition && !zero.hasPosition)
    }

    @Test func holdingStatusGetterMapsLegacyCongelarToQuarentena() throws {
        // SwiftData persists the raw string; older builds wrote "congelar"
        // before the enum was renamed. The getter maps it forward so users
        // upgrading don't lose status.
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "X", quantity: 10, currentPrice: 1,
                        assetClass: .acoesBR, currency: .brl, status: .aportar, targetPercent: 0)
        ctx.insert(h)
        h.statusRaw = "congelar"
        #expect(h.status == .quarentena)
    }

    @Test func holdingPaidDividendsTotalSumsAllPastRecords() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "ITUB3", quantity: 100, currentPrice: 30,
                        assetClass: .acoesBR, currency: .brl, status: .aportar, targetPercent: 0)
        ctx.insert(h)
        let earlier = Self.utcCal.date(byAdding: .month, value: -3, to: Self.asOf)!
        let p1 = DividendPayment(exDate: earlier, paymentDate: earlier, amountPerShare: 1)
        let p2 = DividendPayment(exDate: earlier, paymentDate: earlier, amountPerShare: 2)
        ctx.insert(p1); p1.holding = h
        ctx.insert(p2); p2.holding = h

        let total = h.paidDividendsTotal(in: .brl, rates: StaticRates(brlPerUsd: 5), asOf: Self.asOf)
        // (1 + 2) × 100 shares = 300
        #expect(total.amount == 300)
    }

    @Test func holdingProjectedDividendsTotalSumsFutureRecords() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "AAPL", quantity: 50, currentPrice: 200,
                        assetClass: .usStocks, currency: .usd, status: .aportar, targetPercent: 0)
        ctx.insert(h)
        let later = Self.utcCal.date(byAdding: .month, value: 2, to: Self.asOf)!
        let p = DividendPayment(exDate: later, paymentDate: later, amountPerShare: 1, taxTreatment: .nra30)
        ctx.insert(p); p.holding = h

        let total = h.projectedDividendsTotal(in: .usd, rates: StaticRates(brlPerUsd: 5), asOf: Self.asOf)
        #expect(total.amount == 50)
    }

    @Test func holdingClassifiedDividendsTagsPaidVsProjected() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "ITUB3", quantity: 100, currentPrice: 30,
                        assetClass: .acoesBR, currency: .brl, status: .aportar, targetPercent: 0)
        ctx.insert(h)
        let past = Self.utcCal.date(byAdding: .month, value: -1, to: Self.asOf)!
        let future = Self.utcCal.date(byAdding: .month, value: 1, to: Self.asOf)!
        let p1 = DividendPayment(exDate: past, paymentDate: past, amountPerShare: 1)
        let p2 = DividendPayment(exDate: future, paymentDate: future, amountPerShare: 1)
        ctx.insert(p1); p1.holding = h
        ctx.insert(p2); p2.holding = h

        let classified = h.classifiedDividends(asOf: Self.asOf)
        #expect(classified.count == 2)
        let kinds = classified.map(\.kind)
        #expect(kinds.contains(.paid) && kinds.contains(.projected))
    }

    @Test func holdingClassifiedDividendsWindowFilters() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "ITUB3", quantity: 100, currentPrice: 30,
                        assetClass: .acoesBR, currency: .brl, status: .aportar, targetPercent: 0)
        ctx.insert(h)
        let inMonth = Self.asOf
        let prevMonth = Self.utcCal.date(byAdding: .month, value: -3, to: Self.asOf)!
        let p1 = DividendPayment(exDate: inMonth, paymentDate: inMonth, amountPerShare: 1)
        let p2 = DividendPayment(exDate: prevMonth, paymentDate: prevMonth, amountPerShare: 1)
        ctx.insert(p1); p1.holding = h
        ctx.insert(p2); p2.holding = h

        let monthOnly = h.classifiedDividends(in: .month, asOf: Self.asOf, calendar: Self.utcCal)
        #expect(monthOnly.count == 1)
    }

    // MARK: - UserSettings convenience accessors

    @Test func userSettingsExposesMonthlyCostOfLivingMoney() throws {
        let ctx = try Self.makeContext()
        let s = UserSettings()
        ctx.insert(s)
        s.monthlyCostOfLiving = 5_000
        s.monthlyCostOfLivingCurrency = .brl
        #expect(s.monthlyCostOfLivingMoney.amount == 5_000)
        #expect(s.monthlyCostOfLivingMoney.currency == .brl)
    }

    @Test func userSettingsExposesMonthlyTransactionCapacityMoney() throws {
        let ctx = try Self.makeContext()
        let s = UserSettings()
        ctx.insert(s)
        s.monthlyContributionCapacity = 3_000
        s.monthlyContributionCapacityCurrency = .usd
        #expect(s.monthlyContributionCapacityMoney.amount == 3_000)
        #expect(s.monthlyContributionCapacityMoney.currency == .usd)
    }

    // MARK: - Transaction

    @Test func transactionStoresShareCountAndAmount() throws {
        let ctx = try Self.makeContext()
        let c = Transaction(date: Self.asOf, amount: 1_000, shares: 10, pricePerShare: 100)
        ctx.insert(c)
        #expect(c.shares == 10)
        #expect(c.amount == 1_000)
        #expect(c.pricePerShare == 100)
    }

    // MARK: - TaxTreatment net multipliers

    // MARK: - Holding — quick computed-property exercises

    @Test func holdingDisplayTickerStripsExchangeSuffix() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "ITUB3.SA", quantity: 100, currentPrice: 30,
                        assetClass: .acoesBR, currency: .brl, status: .aportar, targetPercent: 0)
        ctx.insert(h)
        #expect(h.displayTicker == "ITUB3")
    }

    @Test func holdingEnumSettersPersistRawString() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "X", quantity: 0, currentPrice: 0,
                        assetClass: .acoesBR, currency: .brl, status: .estudo, targetPercent: 0)
        ctx.insert(h)
        h.assetClass = .fiis
        h.currency = .usd
        h.status = .vender
        #expect(h.assetClassRaw == AssetClassType.fiis.rawValue)
        #expect(h.currencyRaw == Currency.usd.rawValue)
        #expect(h.statusRaw == HoldingStatus.vender.rawValue)
    }

    @Test func holdingHasCompanyInfoChecksAnyEnrichmentField() throws {
        let ctx = try Self.makeContext()
        let bare = Holding(ticker: "A", quantity: 0, currentPrice: 0,
                           assetClass: .acoesBR, currency: .brl, status: .estudo, targetPercent: 0)
        ctx.insert(bare)
        #expect(bare.hasCompanyInfo == false)

        bare.sector = "Banks"
        #expect(bare.hasCompanyInfo == true)
    }

    @Test func holdingMoneyAndIncomeWrappersUseHoldingCurrency() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "AAPL", quantity: 100,
                        averagePrice: 150, currentPrice: 200, dividendYield: 1.5,
                        assetClass: .usStocks, currency: .usd,
                        status: .aportar, targetPercent: 0)
        ctx.insert(h)
        #expect(h.averagePriceMoney.currency == .usd)
        #expect(h.averagePriceMoney.amount == 150)
        #expect(h.gainLoss == 5_000) // (200-150) × 100
        // estimatedMonthlyIncomeNetMoney falls back to DY × value when no
        // records exist; multiplier for usStocks NRA30 = 0.7.
        let netMoney = h.estimatedMonthlyIncomeNetMoney()
        #expect(netMoney.currency == .usd)
        #expect(netMoney.amount > 0)
    }

    @Test func holdingDividendComputedPropertiesUseNowAsAnchor() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "ITUB3", quantity: 100, currentPrice: 30,
                        assetClass: .acoesBR, currency: .brl, status: .aportar, targetPercent: 0)
        ctx.insert(h)
        let pastDate = Self.utcCal.date(byAdding: .month, value: -1, to: .now)!
        let p = DividendPayment(exDate: pastDate, paymentDate: pastDate, amountPerShare: 1)
        ctx.insert(p); p.holding = h
        // Property variants (no asOf arg) hit the .now-defaulted overloads.
        #expect(h.paidDividends.count == 1)
        #expect(h.projectedDividends.isEmpty)
        #expect(h.classifiedDividends.count == 1)
    }

    @Test func taxTreatmentRawValuesPersistPredictably() {
        // Stored on DividendPayment.taxTreatmentRaw — string contract is part
        // of the persistence schema, mutations would corrupt history.
        for treatment in TaxTreatment.allCases {
            #expect(!treatment.rawValue.isEmpty)
        }
    }
}
