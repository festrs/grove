import Foundation
import SwiftData
import GroveDomain

extension IncomeAggregator {
    /// One month bucket of dividend income — paid (ex-date past `asOf`) and
    /// projected (ex-date future). Sums across holdings, converted to
    /// `displayCurrency`.
    public struct MonthlyIncomePoint: Sendable, Identifiable {
        public let monthStart: Date
        public let paid: Money
        public let projected: Money

        public var total: Money { paid + projected }
        public var id: Date { monthStart }

        public init(monthStart: Date, paid: Money, projected: Money) {
            self.monthStart = monthStart
            self.paid = paid
            self.projected = projected
        }
    }

    /// Trailing 12-month dividend income vs the prior 12-month window.
    /// `percent` is nil when `priorTTM` is zero (insufficient history) so
    /// the UI can hide the row instead of showing "+∞".
    public struct YoYGrowth: Sendable {
        public let currentTTM: Money
        public let priorTTM: Money
        public let percent: Decimal?

        public init(currentTTM: Money, priorTTM: Money, percent: Decimal?) {
            self.currentTTM = currentTTM
            self.priorTTM = priorTTM
            self.percent = percent
        }
    }

    /// One row in the "top dividend payers" list — a holding ranked by its
    /// trailing-12m dividend income with its share of the portfolio's total.
    public struct TopPayer: Sendable, Identifiable {
        public let holdingID: PersistentIdentifier
        public let ticker: String
        public let displayName: String
        public let ttm: Money
        /// 0…100, share of portfolio TTM income.
        public let share: Decimal

        public var id: PersistentIdentifier { holdingID }

        public init(holdingID: PersistentIdentifier, ticker: String, displayName: String, ttm: Money, share: Decimal) {
            self.holdingID = holdingID
            self.ticker = ticker
            self.displayName = displayName
            self.ttm = ttm
            self.share = share
        }
    }

    /// One slice of the income-concentration bar.
    public struct ConcentrationSegment: Sendable, Identifiable {
        public let label: String
        /// 0…100, share of portfolio TTM income.
        public let share: Decimal

        public var id: String { label }

        public init(label: String, share: Decimal) {
            self.label = label
            self.share = share
        }
    }

    /// Income concentration — how much of the user's TTM dividend income comes
    /// from the top N holdings. `topShare` answers the headline ("top 3 = 64%")
    /// and `segments` powers the stacked bar.
    public struct Concentration: Sendable {
        /// 0…100, sum of the top N holdings' shares.
        public let topShare: Decimal
        /// `topN` segments (sorted descending) plus, when there are more
        /// holdings than `topN`, a trailing "Rest" segment so shares sum to 100.
        /// Empty when no holding has any TTM income.
        public let segments: [ConcentrationSegment]

        public init(topShare: Decimal, segments: [ConcentrationSegment]) {
            self.topShare = topShare
            self.segments = segments
        }
    }

    /// Per-month bucketed dividend income for a window starting `lastN`
    /// strictly-past months before `asOf` (offsets -lastN…-1) plus, when
    /// `lookahead > 0`, the current month and the next `lookahead - 1`
    /// months (offsets 0…lookahead-1). Past months populate only `paid`,
    /// future months only `projected`; the current month can carry both.
    /// Buckets are returned oldest-first so charts render left-to-right
    /// without resorting.
    public static func monthlyHistory(
        holdings: [Holding],
        lastN: Int,
        lookahead: Int = 0,
        in displayCurrency: Currency,
        rates: any ExchangeRates,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> [MonthlyIncomePoint] {
        var points: [MonthlyIncomePoint] = []
        let pastOffsets: [Int] = lastN > 0 ? Array((-lastN)...(-1)) : []
        let futureOffsets: [Int] = lookahead > 0 ? Array(0...(lookahead - 1)) : []
        for offset in pastOffsets + futureOffsets {
            guard let anchor = calendar.date(byAdding: .month, value: offset, to: asOf),
                  let interval = calendar.dateInterval(of: .month, for: anchor) else { continue }
            // DateInterval is half-open [start, end); IncomeWindow.custom
            // wants a closed range, so subtract one second from the end.
            let endInclusive = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
            let window = IncomeWindow.custom(start: interval.start, end: endInclusive)

            let paid = holdings
                .map { $0.paidIncome(in: window, asOf: asOf, displayCurrency: displayCurrency,
                                     rates: rates, calendar: calendar) }
                .sum(in: displayCurrency, using: rates)
            let projected = holdings
                .map { $0.projectedIncome(in: window, asOf: asOf, displayCurrency: displayCurrency,
                                          rates: rates, calendar: calendar) }
                .sum(in: displayCurrency, using: rates)

            points.append(
                MonthlyIncomePoint(monthStart: interval.start, paid: paid, projected: projected)
            )
        }
        return points
    }

    /// Trailing-12m dividend income vs the prior 12-month window.
    public static func yoyGrowth(
        holdings: [Holding],
        in displayCurrency: Currency,
        rates: any ExchangeRates,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> YoYGrowth {
        let twelveMoAgo = calendar.date(byAdding: .month, value: -12, to: asOf) ?? asOf
        let twentyFourMoAgo = calendar.date(byAdding: .month, value: -24, to: asOf) ?? asOf

        let currentTTM = sumDividends(
            in: holdings, from: twelveMoAgo, to: asOf,
            displayCurrency: displayCurrency, rates: rates
        )
        let priorTTM = sumDividends(
            in: holdings, from: twentyFourMoAgo, to: twelveMoAgo,
            displayCurrency: displayCurrency, rates: rates
        )

        let percent: Decimal? = priorTTM.amount > 0
            ? ((currentTTM.amount - priorTTM.amount) / priorTTM.amount) * 100
            : nil

        return YoYGrowth(currentTTM: currentTTM, priorTTM: priorTTM, percent: percent)
    }

    /// Per-holding paid dividends in the trailing 12 months. Sums real
    /// `paidIncome` records over the (asOf−12mo, asOf] window — same data
    /// the monthly trend chart visualises and the "paid this month"
    /// headline reads from.
    ///
    /// Used by `topPayers` and `concentration`. Switched away from
    /// `empiricalAnnualGross` because that helper gates by the holding's
    /// first `Contribution`.date, which silently dropped users whose
    /// holdings were added with the default `Contribution.date = .now`
    /// (every backfilled dividend predates the contribution → return 0).
    /// The trend chart never applied that gate, so the two views drifted
    /// apart and these widgets reported "No paying holdings yet" while
    /// the chart clearly showed bars.
    private static func ttmPaid(
        for holding: Holding,
        in displayCurrency: Currency,
        rates: any ExchangeRates,
        asOf: Date,
        calendar: Calendar
    ) -> Money {
        let twelveMoAgo = calendar.date(byAdding: .month, value: -12, to: asOf) ?? asOf
        return holding.paidIncome(
            in: .custom(start: twelveMoAgo, end: asOf),
            asOf: asOf,
            displayCurrency: displayCurrency,
            rates: rates,
            calendar: calendar
        )
    }

    /// Holdings ranked by trailing-12m paid dividend income, descending.
    /// Holdings with zero TTM income are excluded so the list never carries
    /// dead rows. `share` is each holding's percentage of the portfolio's
    /// *non-zero* TTM total — a sole earner reports 100, not its share of
    /// the full portfolio.
    public static func topPayers(
        holdings: [Holding],
        limit: Int,
        in displayCurrency: Currency,
        rates: any ExchangeRates,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> [TopPayer] {
        let pairs: [(Holding, Money)] = holdings.map { h in
            (h, ttmPaid(for: h, in: displayCurrency, rates: rates, asOf: asOf, calendar: calendar))
        }
        let earning = pairs.filter { $0.1.amount > 0 }
        let total = earning.map(\.1).sum(in: displayCurrency, using: rates).amount
        guard total > 0 else { return [] }

        return earning
            .sorted { $0.1.amount > $1.1.amount }
            .prefix(limit)
            .map { h, ttm in
                TopPayer(
                    holdingID: h.persistentModelID,
                    ticker: h.ticker.displayTicker,
                    displayName: h.displayName,
                    ttm: ttm,
                    share: (ttm.amount / total) * 100
                )
            }
    }

    /// Income concentration — top N holdings' combined share + per-segment
    /// breakdown for the stacked bar. The trailing `Rest` segment is only
    /// emitted when there are more income-earning holdings than `topN`.
    public static func concentration(
        holdings: [Holding],
        topN: Int,
        in displayCurrency: Currency,
        rates: any ExchangeRates,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> Concentration {
        let pairs: [(Holding, Money)] = holdings.map { h in
            (h, ttmPaid(for: h, in: displayCurrency, rates: rates, asOf: asOf, calendar: calendar))
        }
        let earning = pairs.filter { $0.1.amount > 0 }
        let total = earning.map(\.1).sum(in: displayCurrency, using: rates).amount
        guard total > 0 else {
            return Concentration(topShare: 0, segments: [])
        }

        let sorted = earning.sorted { $0.1.amount > $1.1.amount }
        let topPairs = Array(sorted.prefix(topN))
        let restPairs = Array(sorted.dropFirst(topN))

        // Build raw shares for top + (optional) Rest. A Decimal divide of
        // non-terminating ratios (e.g. 1/3) leaves trailing-9s dust; if we
        // computed every share independently the segments would sum to 99.99…
        // instead of 100. To stay exact, derive the LAST segment's share
        // from `100 - sum(prior shares)` so the total snaps to 100.
        var labels: [String] = topPairs.map { $0.0.ticker.displayTicker }
        var shares: [Decimal] = topPairs.map { ($0.1.amount / total) * 100 }
        if !restPairs.isEmpty {
            labels.append("Rest")
            shares.append(restPairs.map(\.1.amount).reduce(Decimal.zero, +) / total * 100)
        }
        if let lastIdx = shares.indices.last {
            let priorSum = shares.dropLast().reduce(Decimal.zero, +)
            shares[lastIdx] = Decimal(100) - priorSum
        }

        let segments = zip(labels, shares).map {
            ConcentrationSegment(label: $0.0, share: $0.1)
        }
        // Compute topShare from the raw amounts (which preserve precision
        // when ratios terminate — e.g. 14400/18000 = 0.8 exactly). Deriving
        // it from `100 - rest.share` would re-import the rest segment's
        // rounding correction.
        let topAmount = topPairs.map(\.1.amount).reduce(Decimal.zero, +)
        let topShare: Decimal = restPairs.isEmpty
            ? 100
            : (topAmount / total) * 100
        return Concentration(topShare: topShare, segments: segments)
    }

    // MARK: - Private

    /// Sum of dividend records whose `paymentDate` falls in (`from`, `to`],
    /// scaled by each holding's current `quantity`. Used to compute TTM totals
    /// over arbitrary 12-month windows for YoY math.
    private static func sumDividends(
        in holdings: [Holding],
        from: Date,
        to: Date,
        displayCurrency: Currency,
        rates: any ExchangeRates
    ) -> Money {
        var monies: [Money] = []
        for h in holdings {
            for div in h.dividends where div.paymentDate > from && div.paymentDate <= to {
                monies.append(div.totalAmountMoney)
            }
        }
        return monies.sum(in: displayCurrency, using: rates)
    }
}
