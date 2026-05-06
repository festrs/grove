import Foundation
import SwiftData
import GroveDomain
@testable import Grove

/// Shared in-memory ModelContainer for all tests.
/// SwiftData on iOS 26 crashes when creating too many containers in the same process,
/// so we reuse one and wipe data between tests via `makeTestContext()`.
@MainActor
let sharedTestContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try! ModelContainer(
        for: Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self,
        configurations: config
    )
}()

/// Returns a clean ModelContext by deleting all existing data first.
@MainActor
func makeTestContext() throws -> ModelContext {
    let ctx = sharedTestContainer.mainContext

    // Fetch-then-delete to respect cascade rules (batch delete doesn't).
    let dividends = try ctx.fetch(FetchDescriptor<DividendPayment>())
    dividends.forEach { ctx.delete($0) }
    let contributions = try ctx.fetch(FetchDescriptor<Contribution>())
    contributions.forEach { ctx.delete($0) }
    let holdings = try ctx.fetch(FetchDescriptor<Holding>())
    holdings.forEach { ctx.delete($0) }
    let portfolios = try ctx.fetch(FetchDescriptor<Portfolio>())
    portfolios.forEach { ctx.delete($0) }
    let settings = try ctx.fetch(FetchDescriptor<UserSettings>())
    settings.forEach { ctx.delete($0) }

    try ctx.save()
    return ctx
}

/// Seeds a test context with a portfolio, holdings, and settings.
@MainActor
func seedTestData(_ ctx: ModelContext) -> (portfolio: Portfolio, holdings: [Holding]) {
    let portfolio = Portfolio(name: "Test Portfolio")
    ctx.insert(portfolio)

    // Tickers stored canonical (no `.SA`) — Holding.init normalizes anyway, but
    // keeping the seed in canonical form makes the equality assertions in
    // tests read literally.
    let h1 = Holding(ticker: "ITUB3", displayName: "Itau", quantity: 100, averagePrice: 28, currentPrice: 32, dividendYield: 6, assetClass: .acoesBR, status: .aportar, targetPercent: 5)
    let h2 = Holding(ticker: "BTLG11", displayName: "BTG Logistica", quantity: 50, averagePrice: 95, currentPrice: 100, dividendYield: 8, assetClass: .fiis, status: .aportar, targetPercent: 5)
    let h3 = Holding(ticker: "AAPL", displayName: "Apple", quantity: 10, averagePrice: 150, currentPrice: 180, dividendYield: Decimal(string: "0.5")!, assetClass: .usStocks, currency: .usd, status: .aportar, targetPercent: 5)
    let h4 = Holding(ticker: "WEGE3", displayName: "WEG", quantity: 50, averagePrice: 35, currentPrice: 40, dividendYield: Decimal(string: "1.2")!, assetClass: .acoesBR, status: .estudo, targetPercent: 5)

    let holdings = [h1, h2, h3, h4]
    for h in holdings {
        ctx.insert(h)
        h.portfolio = portfolio
    }

    let settings = UserSettings(monthlyIncomeGoal: 8000, monthlyCostOfLiving: 12000, hasCompletedOnboarding: true)
    settings.classAllocations = [.acoesBR: 40, .fiis: 30, .usStocks: 20, .reits: 10]
    ctx.insert(settings)

    try? ctx.save()

    return (portfolio, holdings)
}
