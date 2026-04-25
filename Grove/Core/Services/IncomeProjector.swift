import Foundation

struct IncomeProjection {
    let currentMonthlyNet: Decimal
    let currentMonthlyGross: Decimal
    let goalMonthly: Decimal
    let progressPercent: Decimal
    let estimatedMonthsToGoal: Int?
    let estimatedYearsToGoal: Decimal?
}

struct IncomeProjector {
    /// Calculate current passive income and time to goal
    static func project(
        holdings: [Holding],
        incomeGoal: Decimal,
        monthlyContribution: Decimal = 5_000,
        exchangeRate: Decimal = 5.12
    ) -> IncomeProjection {
        // Calculate current monthly income (gross and net)
        var grossByClass: [AssetClassType: Decimal] = [:]

        for holding in holdings {
            let monthlyGross = holding.estimatedMonthlyIncome
            let brlMonthly = holding.currency == .usd ? monthlyGross * exchangeRate : monthlyGross
            grossByClass[holding.assetClass, default: 0] += brlMonthly
        }

        let totalGross = grossByClass.values.reduce(Decimal.zero, +)
        let breakdown = TaxCalculator.taxBreakdown(grossByClass: grossByClass)
        let totalNet = breakdown.totalNet

        let progress: Decimal = incomeGoal > 0 ? (totalNet / incomeGoal) * 100 : 0

        // Estimate time to goal
        var estimatedMonths: Int?
        var estimatedYears: Decimal?

        if totalNet < incomeGoal && monthlyContribution > 0 {
            // Simplified model: assume avg DY of portfolio applied to new contributions
            let totalValue = holdings.reduce(Decimal.zero) { sum, h in
                let val = h.currency == .usd ? h.currentValue * exchangeRate : h.currentValue
                return sum + val
            }

            let avgDY: Decimal
            if totalValue > 0 {
                let annualIncome = totalGross * 12
                avgDY = (annualIncome / totalValue) * 100
            } else {
                avgDY = 6 // default assumption
            }

            let avgNetMultiplier: Decimal = totalGross > 0 ? totalNet / totalGross : 0.85
            let monthlyYield = avgDY / 100 / 12

            // Project month by month
            var currentIncome = totalNet
            var months = 0
            let maxMonths = 600 // 50 years cap

            while currentIncome < incomeGoal && months < maxMonths {
                // Each month, new contribution adds to portfolio, generating new yield
                let newMonthlyIncome = monthlyContribution * monthlyYield * avgNetMultiplier
                currentIncome += newMonthlyIncome
                months += 1
            }

            if months < maxMonths {
                estimatedMonths = months
                estimatedYears = Decimal(months) / 12
            }
        } else if totalNet >= incomeGoal {
            estimatedMonths = 0
            estimatedYears = 0
        }

        return IncomeProjection(
            currentMonthlyNet: totalNet,
            currentMonthlyGross: totalGross,
            goalMonthly: incomeGoal,
            progressPercent: min(progress, 100),
            estimatedMonthsToGoal: estimatedMonths,
            estimatedYearsToGoal: estimatedYears
        )
    }
}
