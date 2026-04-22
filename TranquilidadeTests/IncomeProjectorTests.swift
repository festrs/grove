import Testing
import Foundation
@testable import Tranquilidade

struct IncomeProjectorTests {

    // MARK: - Basic Projection

    @Test func projectsCurrentIncome() {
        let holdings = [
            Holding(ticker: "FII1", quantity: 100, currentPrice: 100, dividendYield: 12, assetClass: .fiis, targetPercent: 100),
        ]
        // Annual dividends: 100 × 100 × 12% = 1200. Monthly = 100. FII is exempt.
        let projection = IncomeProjector.project(holdings: holdings, incomeGoal: 1000)

        #expect(projection.currentMonthlyGross == 100)
        #expect(projection.currentMonthlyNet == 100) // FII is exempt
        #expect(projection.goalMonthly == 1000)
    }

    @Test func progressPercentIsCorrect() {
        let holdings = [
            Holding(ticker: "FII1", quantity: 100, currentPrice: 100, dividendYield: 12, assetClass: .fiis, targetPercent: 100),
        ]
        let projection = IncomeProjector.project(holdings: holdings, incomeGoal: 1000)

        // Monthly net = 100, goal = 1000, progress = 10%
        #expect(projection.progressPercent == 10)
    }

    @Test func goalReachedShowsZeroMonths() {
        let holdings = [
            Holding(ticker: "FII1", quantity: 1000, currentPrice: 100, dividendYield: 12, assetClass: .fiis, targetPercent: 100),
        ]
        // Monthly = 1000, goal = 500
        let projection = IncomeProjector.project(holdings: holdings, incomeGoal: 500)

        #expect(projection.estimatedMonthsToGoal == 0)
        #expect(projection.progressPercent == 100) // Capped at 100
    }

    @Test func emptyPortfolioReturnsZero() {
        let projection = IncomeProjector.project(holdings: [], incomeGoal: 10_000)

        #expect(projection.currentMonthlyGross == 0)
        #expect(projection.currentMonthlyNet == 0)
        #expect(projection.progressPercent == 0)
    }

    // MARK: - Tax Impact

    @Test func usStocksReduceNetIncome() {
        let holdings = [
            Holding(ticker: "AAPL", quantity: 100, currentPrice: 100, dividendYield: 12, assetClass: .usStocks, currency: .usd, targetPercent: 100),
        ]
        let projection = IncomeProjector.project(holdings: holdings, incomeGoal: 10_000, exchangeRate: 5)

        // Annual gross: 100 × 100 × 12% = 1200 USD × 5 = 6000 BRL/year → 500/month
        // Net: 500 × 0.70 = 350/month (30% NRA withholding)
        #expect(projection.currentMonthlyGross == 500)
        #expect(projection.currentMonthlyNet == 350)
    }

    // MARK: - Mixed Portfolio

    @Test func mixedPortfolioAggregatesCorrectly() {
        let holdings = [
            Holding(ticker: "FII1", quantity: 100, currentPrice: 100, dividendYield: 12, assetClass: .fiis, targetPercent: 50),
            Holding(ticker: "US1", quantity: 10, currentPrice: 100, dividendYield: 6, assetClass: .usStocks, currency: .usd, targetPercent: 50),
        ]
        let projection = IncomeProjector.project(holdings: holdings, incomeGoal: 10_000, exchangeRate: 5)

        // FII: 100 × 100 × 12% / 12 = 100/month gross, 100 net (exempt)
        // US: 10 × 100 × 6% / 12 = 5 USD/month × 5 = 25 BRL gross, 17.50 net (70%)
        #expect(projection.currentMonthlyGross == 125)
        #expect(projection.currentMonthlyNet == Decimal(string: "117.5"))
    }
}
