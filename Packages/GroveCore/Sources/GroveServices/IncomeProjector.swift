import Foundation
import GroveDomain

public struct IncomeProjection: Sendable {
    public let currentMonthlyNet: Money
    public let currentMonthlyGross: Money
    public let goalMonthly: Money
    public let progressPercent: Decimal
    public let estimatedMonthsToGoal: Int?
    public let estimatedYearsToGoal: Decimal?

    public init(
        currentMonthlyNet: Money,
        currentMonthlyGross: Money,
        goalMonthly: Money,
        progressPercent: Decimal,
        estimatedMonthsToGoal: Int?,
        estimatedYearsToGoal: Decimal?
    ) {
        self.currentMonthlyNet = currentMonthlyNet
        self.currentMonthlyGross = currentMonthlyGross
        self.goalMonthly = goalMonthly
        self.progressPercent = progressPercent
        self.estimatedMonthsToGoal = estimatedMonthsToGoal
        self.estimatedYearsToGoal = estimatedYearsToGoal
    }
}

public struct IncomeProjector {
    /// Calculate current passive income (from real `DividendPayment` records,
    /// paid + projected for the current calendar month) and time to goal.
    /// The goal-sim loop projects future contributions using a portfolio-
    /// weighted DY% derived from `Holding.dividendYield` — that's the only
    /// stable proxy for "what new shares will earn" since they have no
    /// dividend records yet.
    public static func project(
        holdings: [Holding],
        incomeGoal: Money,
        monthlyContribution: Money,
        displayCurrency: Currency,
        rates: any ExchangeRates,
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
        let progress: Decimal = goalDisplay.amount > 0 ? (totalNet.amount / goalDisplay.amount) * 100 : 0

        var estimatedMonths: Int?
        var estimatedYears: Decimal?

        let contributionDisplay = monthlyContribution.converted(to: displayCurrency, using: rates)

        if totalNet.amount < goalDisplay.amount && contributionDisplay.amount > 0 {
            // Sim parameters: stable, portfolio-composition-based.
            let totalValueDisplay = holdings.map { $0.currentValueMoney }
                .sum(in: displayCurrency, using: rates)
            let estAnnualGross = holdings.map { $0.estimatedMonthlyIncomeMoney * 12 }
                .sum(in: displayCurrency, using: rates)
            let avgDY: Decimal
            if totalValueDisplay.amount > 0 && estAnnualGross.amount > 0 {
                avgDY = (estAnnualGross.amount / totalValueDisplay.amount) * 100
            } else {
                avgDY = 6
            }
            let avgNetMultiplier: Decimal = totalGross.amount > 0
                ? totalNet.amount / totalGross.amount
                : 0.85
            let monthlyYield = avgDY / 100 / 12

            var currentIncome = totalNet.amount
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
        } else if totalNet.amount >= goalDisplay.amount {
            estimatedMonths = 0
            estimatedYears = 0
        }

        return IncomeProjection(
            currentMonthlyNet: totalNet,
            currentMonthlyGross: totalGross,
            goalMonthly: goalDisplay,
            progressPercent: min(progress, 100),
            estimatedMonthsToGoal: estimatedMonths,
            estimatedYearsToGoal: estimatedYears
        )
    }
}
