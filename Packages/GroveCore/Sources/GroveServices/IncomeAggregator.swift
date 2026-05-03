import Foundation
import GroveDomain

public struct IncomeWindowSummary: Sendable {
    public let window: IncomeWindow
    public let paid: Money
    public let projected: Money

    public var total: Money { paid + projected }

    public init(window: IncomeWindow, paid: Money, projected: Money) {
        self.window = window
        self.paid = paid
        self.projected = projected
    }
}

public struct PassiveIncomeByClass: Sendable {
    public let assetClass: AssetClassType
    public let paid: Money
    public let projected: Money

    public var total: Money { paid + projected }

    public init(assetClass: AssetClassType, paid: Money, projected: Money) {
        self.assetClass = assetClass
        self.paid = paid
        self.projected = projected
    }
}

/// Aggregates dividend income across holdings using actual `DividendPayment`
/// records — paid dividends (ex-date past) plus projected dividends (future
/// ex-date). Replaces DY-based projection as the source of truth for the
/// passive-income drilldown.
public struct IncomeAggregator {
    public static func summary(
        holdings: [Holding],
        window: IncomeWindow,
        in displayCurrency: Currency,
        rates: any ExchangeRates,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> IncomeWindowSummary {
        let paid = holdings
            .map { $0.paidIncome(in: window, asOf: asOf, displayCurrency: displayCurrency,
                                 rates: rates, calendar: calendar) }
            .reduce(Money.zero(in: displayCurrency)) { $0 + $1 }
        let projected = holdings
            .map { $0.projectedIncome(in: window, asOf: asOf, displayCurrency: displayCurrency,
                                      rates: rates, calendar: calendar) }
            .reduce(Money.zero(in: displayCurrency)) { $0 + $1 }
        return IncomeWindowSummary(window: window, paid: paid, projected: projected)
    }

    /// Per-class breakdown of paid + projected income inside `window`. Sorted
    /// descending by total so the top earners surface first. Classes with
    /// zero income for the window are omitted.
    public static func byClass(
        holdings: [Holding],
        window: IncomeWindow,
        in displayCurrency: Currency,
        rates: any ExchangeRates,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> [PassiveIncomeByClass] {
        var paidByClass: [AssetClassType: Money] = [:]
        var projByClass: [AssetClassType: Money] = [:]

        for h in holdings {
            let paid = h.paidIncome(in: window, asOf: asOf, displayCurrency: displayCurrency,
                                    rates: rates, calendar: calendar)
            let proj = h.projectedIncome(in: window, asOf: asOf, displayCurrency: displayCurrency,
                                         rates: rates, calendar: calendar)
            paidByClass[h.assetClass] = (paidByClass[h.assetClass] ?? .zero(in: displayCurrency)) + paid
            projByClass[h.assetClass] = (projByClass[h.assetClass] ?? .zero(in: displayCurrency)) + proj
        }

        let classes = Set(paidByClass.keys).union(projByClass.keys)
        return classes
            .map { cls in
                PassiveIncomeByClass(
                    assetClass: cls,
                    paid: paidByClass[cls] ?? .zero(in: displayCurrency),
                    projected: projByClass[cls] ?? .zero(in: displayCurrency)
                )
            }
            .filter { $0.total.amount > 0 }
            .sorted { $0.total.amount > $1.total.amount }
    }
}
