import Foundation
import GroveDomain

/// Semantic state for the dashboard "on track for target FI year" pill.
/// The model decides which case applies; the view picks colors and icons.
public enum OnTrackStatus: Sendable, Equatable {
    /// No pill — user has no target year, has reached the goal, or the
    /// projector lacks enough data to classify.
    case hidden
    /// Projection reaches the goal on or before Jan 1 of the target year.
    case onTrack(year: Int)
    /// Behind by 1–36 months (≤3 years).
    case tight(year: Int, yearsShort: Int)
    /// Behind by more than 36 months.
    case far(year: Int, yearsShort: Int)
    /// Sim hit the 50-year cap — the user needs to bump contribution capacity.
    case needTransaction(year: Int)
}

public struct IncomeProjection: Sendable {
    /// Paid + projected dividends for the current calendar month, net of tax.
    /// Hybrid metric kept for callers that explicitly want "what this month
    /// will probably total"; the gauge no longer drives off this because a
    /// quarterly stock or one-off FII payout makes it swing month to month.
    public let currentMonthlyNet: Money
    public let currentMonthlyGross: Money
    /// Strictly real dividends credited in the current calendar month, net of
    /// tax. The "paycheck" view — no projections, no annualization.
    public let paidThisMonthNet: Money
    /// Trailing-12-month real dividends ÷ 12, net of tax. Smooths spiky
    /// payment cadences into a stable run-rate; this is the FI-relevant
    /// number the gauge ring tracks.
    public let annualizedMonthlyNet: Money
    public let goalMonthly: Money
    /// `annualizedMonthlyNet / goalMonthly`, capped at 100. Tracks the
    /// stable run-rate, not the spiky monthly mix, so a heavy payout month
    /// no longer shoots the ring forward.
    public let progressPercent: Decimal
    public let estimatedMonthsToGoal: Int?
    public let estimatedYearsToGoal: Decimal?
    /// User's target FI year. Nil when not set.
    public let targetFIYear: Int?
    /// Months from `asOf` until Jan 1 of `targetFIYear`. Nil when no target year is set.
    public let monthsRemainingToTargetYear: Int?
    /// True when the user can reach the goal before their target FI year at
    /// the current projection. Nil when either piece is missing (no target
    /// year, or `estimatedMonthsToGoal == nil`).
    public let onTrackForTargetYear: Bool?

    public init(
        currentMonthlyNet: Money,
        currentMonthlyGross: Money,
        paidThisMonthNet: Money,
        annualizedMonthlyNet: Money,
        goalMonthly: Money,
        progressPercent: Decimal,
        estimatedMonthsToGoal: Int?,
        estimatedYearsToGoal: Decimal?,
        targetFIYear: Int? = nil,
        monthsRemainingToTargetYear: Int? = nil,
        onTrackForTargetYear: Bool? = nil
    ) {
        self.currentMonthlyNet = currentMonthlyNet
        self.currentMonthlyGross = currentMonthlyGross
        self.paidThisMonthNet = paidThisMonthNet
        self.annualizedMonthlyNet = annualizedMonthlyNet
        self.goalMonthly = goalMonthly
        self.progressPercent = progressPercent
        self.estimatedMonthsToGoal = estimatedMonthsToGoal
        self.estimatedYearsToGoal = estimatedYearsToGoal
        self.targetFIYear = targetFIYear
        self.monthsRemainingToTargetYear = monthsRemainingToTargetYear
        self.onTrackForTargetYear = onTrackForTargetYear
    }

    /// Classify the projection against the target FI year for display in
    /// the on-track pill. Logic lives on the model so views are pure.
    public var targetYearStatus: OnTrackStatus {
        guard let year = targetFIYear, year > 0 else { return .hidden }
        if progressPercent >= 100 { return .hidden }

        if estimatedMonthsToGoal == nil {
            return .needTransaction(year: year)
        }
        guard let onTrack = onTrackForTargetYear else { return .hidden }
        if onTrack { return .onTrack(year: year) }

        let estMonths = estimatedMonthsToGoal ?? 0
        let remMonths = monthsRemainingToTargetYear ?? 0
        let gapMonths = max(estMonths - remMonths, 1)
        let yearsShort = max(1, Int((Double(gapMonths) / 12.0).rounded(.up)))
        let isTight = gapMonths <= 36
        return isTight
            ? .tight(year: year, yearsShort: yearsShort)
            : .far(year: year, yearsShort: yearsShort)
    }
}

public struct IncomeProjector {
    /// Calculate current passive income (from real `DividendPayment` records,
    /// paid + projected for the current calendar month) and time to goal.
    /// The goal-sim loop projects future contributions using a portfolio-
    /// weighted DY% derived from `Holding.dividendYield` — that's the only
    /// stable proxy for "what new shares will earn" since they have no
    /// dividend records yet.
    ///
    /// When `targetYear` is supplied, also reports months remaining until
    /// Jan 1 of that year and whether the user is on track to hit the goal
    /// before then.
    public static func project(
        holdings: [Holding],
        incomeGoal: Money,
        monthlyContribution: Money,
        displayCurrency: Currency,
        rates: any ExchangeRates,
        targetYear: Int? = nil,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> IncomeProjection {
        // Real-data current monthly (paid + projected, this calendar month).
        let summary = IncomeAggregator.summary(
            holdings: holdings, window: .month,
            in: displayCurrency, rates: rates,
            asOf: asOf, calendar: calendar
        )
        var grossByClass: [AssetClassType: Money] = [:]
        for h in holdings {
            let paid = h.paidIncome(in: .month, asOf: asOf, displayCurrency: displayCurrency,
                                    rates: rates, calendar: calendar)
            let proj = h.projectedIncome(in: .month, asOf: asOf, displayCurrency: displayCurrency,
                                         rates: rates, calendar: calendar)
            let g = paid + proj
            grossByClass[h.assetClass] = (grossByClass[h.assetClass] ?? .zero(in: displayCurrency)) + g
        }
        let breakdown = TaxCalculator.taxBreakdown(
            grossByClass: grossByClass,
            displayCurrency: displayCurrency,
            rates: rates
        )
        let totalGross = summary.total
        let totalNet = breakdown.totalNet
        let goalDisplay = incomeGoal.converted(to: displayCurrency, using: rates)

        // Paid this month: strictly real dividends with paymentDate inside
        // the current calendar month. No projections — this is the user's
        // actual paycheck.
        var paidGrossByClass: [AssetClassType: Money] = [:]
        for h in holdings {
            let p = h.paidIncome(in: .month, asOf: asOf, displayCurrency: displayCurrency,
                                 rates: rates, calendar: calendar)
            paidGrossByClass[h.assetClass] = (paidGrossByClass[h.assetClass] ?? .zero(in: displayCurrency)) + p
        }
        let paidBreakdown = TaxCalculator.taxBreakdown(
            grossByClass: paidGrossByClass,
            displayCurrency: displayCurrency,
            rates: rates
        )
        let paidThisMonthNet = paidBreakdown.totalNet

        // Annualized run-rate: per-holding `estimatedMonthlyIncomeMoney`
        // already returns trailing-12-month real dividends ÷ 12, falling back
        // to `value × DY/100 / 12` when no records exist yet. Same math the
        // dashboard "Avg Net /mo (TTM)" stat card displays, so the gauge
        // and that card always agree. `empiricalAnnualGross` alone would
        // read R$ 0 on a brand-new portfolio (no records yet) even when the
        // user has populated DY for each holding.
        var monthlyGrossByClass: [AssetClassType: Money] = [:]
        for h in holdings {
            let g = h.estimatedMonthlyIncomeMoney(asOf: asOf, calendar: calendar)
                .converted(to: displayCurrency, using: rates)
            monthlyGrossByClass[h.assetClass] = (monthlyGrossByClass[h.assetClass] ?? .zero(in: displayCurrency)) + g
        }
        let runRateBreakdown = TaxCalculator.taxBreakdown(
            grossByClass: monthlyGrossByClass,
            displayCurrency: displayCurrency,
            rates: rates
        )
        let annualizedMonthlyNet = runRateBreakdown.totalNet

        let progress: Decimal = goalDisplay.amount > 0
            ? (annualizedMonthlyNet.amount / goalDisplay.amount) * 100
            : 0

        var estimatedMonths: Int?
        var estimatedYears: Decimal?

        let contributionDisplay = monthlyContribution.converted(to: displayCurrency, using: rates)

        if annualizedMonthlyNet.amount < goalDisplay.amount && contributionDisplay.amount > 0 {
            // Sim parameters: stable, portfolio-composition-based.
            let totalValueDisplay = holdings.map { $0.currentValueMoney }
                .sum(in: displayCurrency, using: rates)
            // Two estimates of forward yield:
            //   - Empirical: trailing-12-month real dividend records, scaled
            //     by current quantity. Authoritative once a holding has paid.
            //   - Stored: `dividendYield × price × qty / 12` × 12 from the
            //     holding's `dividendYield` field. Best signal for brand-new
            //     holdings with no records yet, but stale otherwise.
            // Take the per-portfolio max so users with a real dividend
            // history get the truthful number, while users with empty
            // history still get the optimistic stored estimate they entered.
            let empiricalAnnualGross = holdings.map {
                $0.empiricalAnnualGross(asOf: asOf, displayCurrency: displayCurrency,
                                        rates: rates, calendar: calendar)
            }.sum(in: displayCurrency, using: rates)
            let storedAnnualGross = holdings.map {
                Money(amount: $0.currentValue * $0.dividendYield / 100, currency: $0.currency)
            }.sum(in: displayCurrency, using: rates)
            let bestAnnualGross = max(empiricalAnnualGross.amount, storedAnnualGross.amount)
            let avgDY: Decimal
            if totalValueDisplay.amount > 0 && bestAnnualGross > 0 {
                avgDY = (bestAnnualGross / totalValueDisplay.amount) * 100
            } else {
                avgDY = 6
            }
            let avgNetMultiplier: Decimal = totalGross.amount > 0
                ? totalNet.amount / totalGross.amount
                : 0.85
            let monthlyYield = avgDY / 100 / 12

            var currentIncome = annualizedMonthlyNet.amount
            var months = 0
            let maxMonths = 600

            while currentIncome < goalDisplay.amount && months < maxMonths {
                currentIncome += contributionDisplay.amount * monthlyYield * avgNetMultiplier
                months += 1
            }

            if months < maxMonths {
                estimatedMonths = months
                estimatedYears = Decimal(months) / 12
            }
        } else if annualizedMonthlyNet.amount >= goalDisplay.amount {
            estimatedMonths = 0
            estimatedYears = 0
        }

        // Target-year reporting (independent of the sim above).
        var monthsRemaining: Int?
        var onTrack: Bool?
        var resolvedTargetYear: Int?
        if let targetYear, targetYear > 0 {
            resolvedTargetYear = targetYear
            var components = DateComponents()
            components.year = targetYear
            components.month = 1
            components.day = 1
            if let target = calendar.date(from: components) {
                let diff = calendar.dateComponents([.month], from: asOf, to: target).month ?? 0
                monthsRemaining = max(diff, 0)
                if let estimatedMonths {
                    onTrack = estimatedMonths <= max(diff, 0)
                }
            }
        }

        return IncomeProjection(
            currentMonthlyNet: totalNet,
            currentMonthlyGross: totalGross,
            paidThisMonthNet: paidThisMonthNet,
            annualizedMonthlyNet: annualizedMonthlyNet,
            goalMonthly: goalDisplay,
            progressPercent: min(progress, 100),
            estimatedMonthsToGoal: estimatedMonths,
            estimatedYearsToGoal: estimatedYears,
            targetFIYear: resolvedTargetYear,
            monthsRemainingToTargetYear: monthsRemaining,
            onTrackForTargetYear: onTrack
        )
    }
}
