import Foundation
import SwiftData
@testable import Tranquilidade

/// Creates an in-memory ModelContainer for testing ViewModels that need SwiftData.
@MainActor
func makeTestContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self,
        configurations: config
    )
    return container.mainContext
}

/// Seeds a test context with a portfolio, holdings, and settings.
@MainActor
func seedTestData(_ ctx: ModelContext) -> (portfolio: Portfolio, holdings: [Holding]) {
    let portfolio = Portfolio(name: "Test Portfolio")
    portfolio.classAllocations = [.acoesBR: 40, .fiis: 30, .usStocks: 20, .reits: 10]
    ctx.insert(portfolio)

    let holdings: [Holding] = [
        Holding(ticker: "ITUB3.SA", displayName: "Itau", quantity: 100, averagePrice: 28, currentPrice: 32, dividendYield: 6, assetClass: .acoesBR, status: .aportar, targetPercent: 5),
        Holding(ticker: "BTLG11.SA", displayName: "BTG Logistica", quantity: 50, averagePrice: 95, currentPrice: 100, dividendYield: 8, assetClass: .fiis, status: .aportar, targetPercent: 5),
        Holding(ticker: "AAPL", displayName: "Apple", quantity: 10, averagePrice: 150, currentPrice: 180, dividendYield: 0.5, assetClass: .usStocks, currency: .usd, status: .aportar, targetPercent: 5),
        Holding(ticker: "WEGE3.SA", displayName: "WEG", quantity: 50, averagePrice: 35, currentPrice: 40, dividendYield: 1.2, assetClass: .acoesBR, status: .congelar, targetPercent: 5),
    ]
    for h in holdings {
        h.portfolio = portfolio
        ctx.insert(h)
    }

    let settings = UserSettings(monthlyIncomeGoal: 8000, monthlyCostOfLiving: 12000, hasCompletedOnboarding: true)
    ctx.insert(settings)

    return (portfolio, holdings)
}
