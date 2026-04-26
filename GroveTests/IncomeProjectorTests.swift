import Testing
import Foundation
@testable import Grove

struct IncomeProjectorTests {

    private var rates: any ExchangeRates { StaticRates(brlPerUsd: 5) }
    private var brlGoal: Money { Money(amount: 1000, currency: .brl) }
    private var brlContribution: Money { Money(amount: 5_000, currency: .brl) }

    // MARK: - Basic Projection

    @Test func projectsCurrentIncome() {
        let holdings = [
            Holding(ticker: "FII1", quantity: 100, currentPrice: 100, dividendYield: 12, assetClass: .fiis, targetPercent: 100),
        ]
        let projection = IncomeProjector.project(
            holdings: holdings,
            incomeGoal: brlGoal,
            monthlyContribution: brlContribution,
            displayCurrency: .brl,
            rates: rates
        )

        #expect(projection.currentMonthlyGross.amount == 100)
        #expect(projection.currentMonthlyGross.currency == .brl)
        #expect(projection.currentMonthlyNet.amount == 100)
        #expect(projection.goalMonthly.amount == 1000)
    }

    @Test func progressPercentIsCorrect() {
        let holdings = [
            Holding(ticker: "FII1", quantity: 100, currentPrice: 100, dividendYield: 12, assetClass: .fiis, targetPercent: 100),
        ]
        let projection = IncomeProjector.project(
            holdings: holdings,
            incomeGoal: brlGoal,
            monthlyContribution: brlContribution,
            displayCurrency: .brl,
            rates: rates
        )

        #expect(projection.progressPercent == 10)
    }

    @Test func projectionLoopEstimatesMonthsWhenBelowGoal() {
        // gross = 100 BRL/mo, goal = 1000 BRL, contribution = 5000 BRL.
        // avgDY = (1200 / 10000) * 100 = 12%; monthly yield = 0.01; net mult = 1.
        // Each iteration adds 5000 * 0.01 = 50 to current income.
        // Starting at 100, needs 18 months to reach 1000.
        let holdings = [
            Holding(ticker: "FII1", quantity: 100, currentPrice: 100, dividendYield: 12, assetClass: .fiis, targetPercent: 100),
        ]
        let projection = IncomeProjector.project(
            holdings: holdings,
            incomeGoal: brlGoal,
            monthlyContribution: brlContribution,
            displayCurrency: .brl,
            rates: rates
        )

        #expect(projection.estimatedMonthsToGoal == 18, "Loop must run when income is below goal — mutation flipping < to > would skip it and return nil")
        #expect(projection.estimatedYearsToGoal == Decimal(18) / 12)
    }

    @Test func goalReachedShowsZeroMonths() {
        let holdings = [
            Holding(ticker: "FII1", quantity: 1000, currentPrice: 100, dividendYield: 12, assetClass: .fiis, targetPercent: 100),
        ]
        let projection = IncomeProjector.project(
            holdings: holdings,
            incomeGoal: Money(amount: 500, currency: .brl),
            monthlyContribution: brlContribution,
            displayCurrency: .brl,
            rates: rates
        )

        #expect(projection.estimatedMonthsToGoal == 0)
        #expect(projection.progressPercent == 100)
    }

    @Test func emptyPortfolioReturnsZero() {
        let projection = IncomeProjector.project(
            holdings: [],
            incomeGoal: Money(amount: 10_000, currency: .brl),
            monthlyContribution: brlContribution,
            displayCurrency: .brl,
            rates: rates
        )

        #expect(projection.currentMonthlyGross.amount == 0)
        #expect(projection.currentMonthlyNet.amount == 0)
        #expect(projection.progressPercent == 0)
    }

    // MARK: - Tax Impact

    @Test func usStocksReduceNetIncome() {
        let holdings = [
            Holding(ticker: "AAPL", quantity: 100, currentPrice: 100, dividendYield: 12, assetClass: .usStocks, currency: .usd, targetPercent: 100),
        ]
        let projection = IncomeProjector.project(
            holdings: holdings,
            incomeGoal: Money(amount: 10_000, currency: .brl),
            monthlyContribution: brlContribution,
            displayCurrency: .brl,
            rates: rates
        )

        #expect(projection.currentMonthlyGross.amount == 500)
        #expect(projection.currentMonthlyNet.amount == 350)
    }

    // MARK: - Mixed Portfolio

    @Test func mixedPortfolioAggregatesCorrectly() {
        let holdings = [
            Holding(ticker: "FII1", quantity: 100, currentPrice: 100, dividendYield: 12, assetClass: .fiis, targetPercent: 50),
            Holding(ticker: "US1", quantity: 10, currentPrice: 100, dividendYield: 6, assetClass: .usStocks, currency: .usd, targetPercent: 50),
        ]
        let projection = IncomeProjector.project(
            holdings: holdings,
            incomeGoal: Money(amount: 10_000, currency: .brl),
            monthlyContribution: brlContribution,
            displayCurrency: .brl,
            rates: rates
        )

        #expect(projection.currentMonthlyGross.amount == 125)
        #expect(projection.currentMonthlyNet.amount == Decimal(string: "117.5"))
    }
}
