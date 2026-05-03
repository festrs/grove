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

    @Relationship(deleteRule: .cascade, inverse: \Contribution.holding)
    public var contributions: [Contribution]

    // MARK: - Computed Properties

    public var displayTicker: String {
        ticker.replacingOccurrences(of: ".SA", with: "")
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

    public var estimatedMonthlyIncomeMoney: Money {
        Money(amount: estimatedMonthlyIncome, currency: currency)
    }

    public var estimatedMonthlyIncomeNetMoney: Money {
        Money(amount: estimatedMonthlyIncomeNet, currency: currency)
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
    /// contribution-date gating: Passive Income shows all recorded
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
    /// paid (ex-date past `asOf` and on/after first contribution).
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

    /// Estimated monthly dividend income (gross)
    public var estimatedMonthlyIncome: Decimal {
        guard dividendYield > 0 else { return 0 }
        return (currentValue * dividendYield / 100) / 12
    }

    /// Estimated monthly dividend income (net of taxes)
    public var estimatedMonthlyIncomeNet: Decimal {
        estimatedMonthlyIncome * assetClass.defaultTaxTreatment.netMultiplier
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
        self.ticker = ticker
        self.displayName = displayName.isEmpty ? ticker : displayName
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
        self.contributions = []
    }

    // MARK: - Contribution-Based Recalculation

    /// Recomputes quantity and averagePrice from the contributions ledger.
    /// Call this after inserting a new Contribution.
    public func recalculateFromContributions() {
        var totalShares: Decimal = 0
        var totalCost: Decimal = 0

        for c in contributions.sorted(by: { $0.date < $1.date }) {
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
