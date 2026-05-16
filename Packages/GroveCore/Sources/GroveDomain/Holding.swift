import Foundation
import SwiftData

@Model
public final class Holding {
    public var ticker: String
    public var displayName: String
    public var quantity: Decimal
    public var averagePrice: Decimal
    public var currentPrice: Decimal
    public var dividendYield: Decimal

    // Stored as raw strings for SwiftData compatibility
    public var assetClassRaw: String
    public var currencyRaw: String
    public var statusRaw: String

    public var targetPercent: Decimal
    public var lastPriceUpdate: Date?

    /// Custom (user-created) holdings are local-only — the backend has no
    /// quote, dividends, or symbol for them. Sync, ticker bootstrap, and the
    /// dividend scrape must skip these so they never trigger best-effort
    /// failures or stomp the user's manually entered price.
    public var isCustom: Bool = false

    // Optional enrichment data
    public var sector: String?
    public var logoURL: String?
    public var marketCap: String?

    public var portfolio: Portfolio?

    @Relationship(deleteRule: .cascade, inverse: \DividendPayment.holding)
    public var dividends: [DividendPayment]

    @Relationship(deleteRule: .cascade, inverse: \Transaction.holding)
    public var transactions: [Transaction]

    // MARK: - Computed Properties

    public var displayTicker: String {
        ticker.displayTicker
    }

    public var assetClass: AssetClassType {
        get { AssetClassType(rawValue: assetClassRaw) ?? .acoesBR }
        set { assetClassRaw = newValue.rawValue }
    }

    public var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .brl }
        set { currencyRaw = newValue.rawValue }
    }

    public var status: HoldingStatus {
        get {
            if statusRaw == "congelar" { return .quarentena }
            return HoldingStatus(rawValue: statusRaw) ?? .aportar
        }
        set { statusRaw = newValue.rawValue }
    }

    public var hasPosition: Bool {
        quantity > 0
    }

    public var hasCompanyInfo: Bool {
        sector != nil || marketCap != nil || logoURL != nil
    }

    /// Custom holdings have no backend record, so the chart, fundamentals,
    /// company-info, and dividend-history sections of detail screens have
    /// nothing to show. Three flags so callers don't have to repeat the
    /// `!isCustom && ...` chain at every site.
    public var hasBackendEnrichment: Bool { !isCustom }

    public var hasPriceChartContent: Bool {
        !isCustom && assetClass.hasPriceHistory
    }

    public var hasDividendHistoryContent: Bool {
        !isCustom && assetClass.hasDividends
    }

    /// Most-recent transactions, newest first, capped to a UI-friendly
    /// page size. The cap matches the original detail-view slice; bump it
    /// if a future screen wants more history.
    public var recentTransactions: [Transaction] {
        Array(transactions.sorted { $0.date > $1.date }.prefix(15))
    }

    public var currentValue: Decimal {
        quantity * currentPrice
    }

    public var totalCost: Decimal {
        quantity * averagePrice
    }

    public var priceMoney: Money {
        Money(amount: currentPrice, currency: currency)
    }

    public var averagePriceMoney: Money {
        Money(amount: averagePrice, currency: currency)
    }

    public var currentValueMoney: Money {
        Money(amount: currentPrice * quantity, currency: currency)
    }

    public func estimatedMonthlyIncomeMoney(
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> Money {
        Money(amount: estimatedMonthlyIncome(asOf: asOf, calendar: calendar), currency: currency)
    }

    public func estimatedMonthlyIncomeNetMoney(
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> Money {
        Money(amount: estimatedMonthlyIncomeNet(asOf: asOf, calendar: calendar), currency: currency)
    }

    public var gainLoss: Decimal {
        currentValue - totalCost
    }

    public var gainLossPercent: Decimal {
        guard totalCost > 0 else { return 0 }
        return (gainLoss / totalCost) * 100
    }

    /// Holding's share of `totalValue`, expressed as a percentage in
    /// `displayCurrency`. Returns 0 when the portfolio is empty.
    public func currentPercent(
        of totalValue: Money,
        in displayCurrency: Currency,
        rates: any ExchangeRates
    ) -> Decimal {
        guard totalValue.amount > 0 else { return 0 }
        let displayValue = currentValueMoney.converted(to: displayCurrency, using: rates).amount
        return (displayValue / totalValue.amount) * 100
    }

    /// Distance from `targetPercent` (positive = under target / needs more buy).
    /// Used to rank holdings when distributing a rebalancing budget.
    public func allocationGap(
        totalValue: Money,
        in displayCurrency: Currency,
        rates: any ExchangeRates
    ) -> Decimal {
        targetPercent - currentPercent(of: totalValue, in: displayCurrency, rates: rates)
    }

    /// Past dividends — every record with `exDate <= asOf`. No
    /// transaction-date gating: Passive Income shows all recorded
    /// dividends, totals scale by current `quantity` (study-mode
    /// holdings naturally contribute zero).
    public func paidDividends(asOf: Date) -> [DividendPayment] {
        dividends
            .filter { $0.exDate <= asOf }
            .sorted { $0.paymentDate > $1.paymentDate }
    }

    public var paidDividends: [DividendPayment] { paidDividends(asOf: .now) }

    /// Future dividends — every record with `exDate > asOf`. Sorted by
    /// payment date ascending so the next payment surfaces first.
    public func projectedDividends(asOf: Date) -> [DividendPayment] {
        dividends
            .filter { $0.exDate > asOf }
            .sorted { $0.paymentDate < $1.paymentDate }
    }

    public var projectedDividends: [DividendPayment] { projectedDividends(asOf: .now) }

    /// Every dividend on this holding, sorted by payment date descending
    /// and tagged paid / projected relative to `asOf`. Drives the per-class
    /// income drilldown — see `DividendKind`.
    public func classifiedDividends(asOf: Date) -> [ClassifiedDividend] {
        dividends
            .sorted { $0.paymentDate > $1.paymentDate }
            .map { payment in
                let kind: DividendKind = payment.exDate <= asOf ? .paid : .projected
                return ClassifiedDividend(payment: payment, kind: kind)
            }
    }

    public var classifiedDividends: [ClassifiedDividend] { classifiedDividends(asOf: .now) }

    /// `classifiedDividends` filtered to payments whose `paymentDate` falls
    /// inside `window`. Used by the per-class drilldown so the listed
    /// payments match the window the user picked on the parent screen.
    public func classifiedDividends(
        in window: IncomeWindow,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> [ClassifiedDividend] {
        let range = window.dateRange(asOf: asOf, calendar: calendar)
        return classifiedDividends(asOf: asOf)
            .filter { range.contains($0.payment.paymentDate) }
    }

    /// Sum of `paidDividends` totals, converted to `displayCurrency`. Excludes
    /// projected and informational rows so the figure matches what the user
    /// actually received.
    public func paidDividendsTotal(
        in displayCurrency: Currency,
        rates: any ExchangeRates,
        asOf: Date = .now
    ) -> Money {
        paidDividends(asOf: asOf).map(\.totalAmountMoney).sum(in: displayCurrency, using: rates)
    }

    /// Sum of `projectedDividends` totals, converted to `displayCurrency`.
    /// What the user is expected to receive going forward at the current
    /// share count.
    public func projectedDividendsTotal(
        in displayCurrency: Currency,
        rates: any ExchangeRates,
        asOf: Date = .now
    ) -> Money {
        projectedDividends(asOf: asOf).map(\.totalAmountMoney).sum(in: displayCurrency, using: rates)
    }

    // MARK: - Windowed income (paid + projected over day/week/month/year)
    // NOTE: `DividendPayment.totalAmount` uses current `quantity`. For
    // projected this is correct (best proxy for future shares). For paid it
    // is slightly revisionist if the share count has changed since the
    // payment. Tracking historical share count at ex-date is a follow-up.

    /// Sum of dividends with `paymentDate` inside `window` AND classified as
    /// paid (ex-date past `asOf` and on/after first transaction).
    public func paidIncome(
        in window: IncomeWindow,
        asOf: Date = .now,
        displayCurrency: Currency,
        rates: any ExchangeRates,
        calendar: Calendar = .current
    ) -> Money {
        let range = window.dateRange(asOf: asOf, calendar: calendar)
        return paidDividends(asOf: asOf)
            .filter { range.contains($0.paymentDate) }
            .map(\.totalAmountMoney)
            .sum(in: displayCurrency, using: rates)
    }

    /// Sum of dividends with `paymentDate` inside `window` AND classified as
    /// projected (ex-date in the future).
    public func projectedIncome(
        in window: IncomeWindow,
        asOf: Date = .now,
        displayCurrency: Currency,
        rates: any ExchangeRates,
        calendar: Calendar = .current
    ) -> Money {
        let range = window.dateRange(asOf: asOf, calendar: calendar)
        return projectedDividends(asOf: asOf)
            .filter { range.contains($0.paymentDate) }
            .map(\.totalAmountMoney)
            .sum(in: displayCurrency, using: rates)
    }

    /// Annualized gross dividend rate projected forward from the trailing
    /// 12 months of real `DividendPayment` records, scoped to **received
    /// while owned**. Per-share rate × current `quantity` so a recent
    /// quantity bump scales cleanly. When the holding has been held for
    /// less than 12 months, the partial window is scaled up to a full
    /// year — three months of records at R$1/share don't get reported as
    /// a quarter-yield portfolio.
    ///
    /// Backfill safety: providers like Status Invest serve full historical
    /// dividend history (2007 → now). Counting payments from before the
    /// user owned the asset and *then* annualizing produces a 12/monthsHeld×
    /// inflation (e.g., 4 months held + 12 months of records → 3× too
    /// high). The window's effective cutoff is `max(twelve-months-ago,
    /// firstTransaction)` so annualization only scales actually-received
    /// cashflows.
    ///
    /// When the holding has no `Transaction` records (older positions or
    /// import paths that never seeded one), ownership-start is unknown — we
    /// fall back to `twelveMonthsAgo` rather than `asOf`. The earlier `asOf`
    /// default collapsed the window to empty and silently returned 0, which
    /// hid these holdings from `topPayers`, `concentration`, and the dashboard
    /// run-rate even when they had real dividend records. Trading the
    /// partial-window scale-up for a non-zero, slightly-pessimistic reading
    /// matches what the trend chart and paid-this-month already display.
    ///
    /// Returns zero when no records fall in the (effective-cutoff, asOf]
    /// window or quantity is zero.
    public func empiricalAnnualGross(
        asOf: Date = .now,
        displayCurrency: Currency,
        rates: any ExchangeRates,
        calendar: Calendar = .current
    ) -> Money {
        guard quantity > 0 else { return .zero(in: currency) }

        let twelveMonthsAgo = calendar.date(byAdding: .month, value: -12, to: asOf) ?? asOf
        let firstTransaction = transactions.map(\.date).min() ?? twelveMonthsAgo
        let effectiveCutoff = max(twelveMonthsAgo, firstTransaction)

        let recent = dividends.filter {
            $0.paymentDate > effectiveCutoff && $0.paymentDate <= asOf
        }
        guard !recent.isEmpty else { return .zero(in: currency) }

        let totalPerShare = recent.map(\.amountPerShare).reduce(Decimal.zero, +)

        let monthsHeld = max(1, calendar.dateComponents([.month], from: firstTransaction, to: asOf).month ?? 12)
        let annualizationFactor: Decimal = monthsHeld < 12
            ? Decimal(12) / Decimal(monthsHeld)
            : 1

        let annualPerShare = totalPerShare * annualizationFactor
        let annualNative = Money(amount: annualPerShare * quantity, currency: currency)
        return annualNative.converted(to: displayCurrency, using: rates)
    }

    /// Estimated monthly dividend income (gross), in this holding's native
    /// currency. Sourced from trailing-12m `DividendPayment` records via
    /// `empiricalAnnualGross` (which annualizes partial windows). Falls back
    /// to `currentValue × dividendYield / 100 / 12` only when no records exist
    /// (newly added, `isCustom`, or brand-new IPO).
    public func estimatedMonthlyIncome(
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> Decimal {
        let ttmAnnual = empiricalAnnualGross(
            asOf: asOf,
            displayCurrency: currency,
            rates: IdentityRates(),
            calendar: calendar
        )
        if ttmAnnual.amount > 0 {
            return ttmAnnual.amount / 12
        }
        guard dividendYield > 0 else { return 0 }
        return (currentValue * dividendYield / 100) / 12
    }

    /// Estimated monthly dividend income (net of taxes), in native currency.
    public func estimatedMonthlyIncomeNet(
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> Decimal {
        estimatedMonthlyIncome(asOf: asOf, calendar: calendar) * assetClass.defaultTaxTreatment.netMultiplier
    }

    public init(
        ticker: String,
        displayName: String = "",
        quantity: Decimal = 0,
        averagePrice: Decimal = 0,
        currentPrice: Decimal = 0,
        dividendYield: Decimal = 0,
        assetClass: AssetClassType,
        currency: Currency? = nil,
        status: HoldingStatus = .estudo,
        targetPercent: Decimal = 5,
        isCustom: Bool = false
    ) {
        let canonical = ticker.normalizedTicker
        self.ticker = canonical
        self.displayName = displayName.isEmpty ? canonical.displayTicker : displayName
        self.quantity = quantity
        self.averagePrice = averagePrice
        self.currentPrice = currentPrice
        self.dividendYield = dividendYield
        self.assetClassRaw = assetClass.rawValue
        self.currencyRaw = (currency ?? assetClass.defaultCurrency).rawValue
        self.statusRaw = status.rawValue
        self.targetPercent = targetPercent
        self.isCustom = isCustom
        self.dividends = []
        self.transactions = []
    }

    // MARK: - Transaction-Based Recalculation

    /// Recomputes quantity and averagePrice from the transactions ledger.
    /// Call this after inserting a new Transaction.
    public func recalculateFromTransactions() {
        var totalShares: Decimal = 0
        var totalCost: Decimal = 0

        for c in transactions.sorted(by: { $0.date < $1.date }) {
            if c.shares > 0 {
                // Buy: add to cost basis
                totalCost += c.shares * c.pricePerShare
                totalShares += c.shares
            } else {
                // Sell: reduce shares, keep average price (cost basis reduces proportionally)
                let sellShares = abs(c.shares)
                if totalShares > 0 {
                    let avgAtSale = totalCost / totalShares
                    totalCost -= sellShares * avgAtSale
                }
                totalShares -= sellShares
            }
        }

        quantity = max(totalShares, 0)
        averagePrice = quantity > 0 ? totalCost / quantity : 0
    }
}
