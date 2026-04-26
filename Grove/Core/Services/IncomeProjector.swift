import Foundation

struct IncomeProjection {
    let currentMonthlyNet: Money
    let currentMonthlyGross: Money
    let goalMonthly: Money
    let progressPercent: Decimal
    let estimatedMonthsToGoal: Int?
    let estimatedYearsToGoal: Decimal?
}

struct IncomeProjector {
    /// Calculate current passive income and time to goal.
    /// Goal is provided as Money so its currency carries semantics.
    /// Aggregates and projections render in `displayCurrency`.
    static func project(
        holdings: [Holding],
        incomeGoal: Money,
        monthlyContribution: Money,
        displayCurrency: Currency,
        rates: any ExchangeRates
    ) -> IncomeProjection {
        var grossByClass: [AssetClassType: Money] = [:]
        var grossValues: [Money] = []

        for holding in holdings {
            let monthlyGross = holding.estimatedMonthlyIncomeMoney
            grossValues.append(monthlyGross)
            grossByClass[holding.assetClass] = (grossByClass[holding.assetClass] ?? .zero(in: holding.currency)) + monthlyGross
        }

        let totalGross = grossValues.sum(in: displayCurrency, using: rates)
        let breakdown = TaxCalculator.taxBreakdown(
            grossByClass: grossByClass,
            displayCurrency: displayCurrency,
            rates: rates
        )
        let totalNet = breakdown.totalNet
        let goalDisplay = incomeGoal.converted(to: displayCurrency, using: rates)

        let progress: Decimal = goalDisplay.amount > 0 ? (totalNet.amount / goalDisplay.amount) * 100 : 0

        var estimatedMonths: Int?
        var estimatedYears: Decimal?

        let contributionDisplay = monthlyContribution.converted(to: displayCurrency, using: rates)
        let totalValueDisplay = holdings.map { $0.currentValueMoney }.sum(in: displayCurrency, using: rates)

        if totalNet.amount < goalDisplay.amount && contributionDisplay.amount > 0 {
            let avgDY: Decimal
            if totalValueDisplay.amount > 0 {
                let annualIncome = totalGross.amount * 12
                avgDY = (annualIncome / totalValueDisplay.amount) * 100
            } else {
                avgDY = 6
            }

            let avgNetMultiplier: Decimal = totalGross.amount > 0 ? totalNet.amount / totalGross.amount : 0.85
            let monthlyYield = avgDY / 100 / 12

            var currentIncome = totalNet.amount
            var months = 0
            let maxMonths = 600

            while currentIncome < goalDisplay.amount && months < maxMonths {
                let newMonthlyIncome = contributionDisplay.amount * monthlyYield * avgNetMultiplier
                currentIncome += newMonthlyIncome
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
