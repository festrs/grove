import Testing
import Foundation
import SwiftData
import GroveDomain
import GroveRepositories

@MainActor
struct PortfolioRepositoryTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([Portfolio.self, Holding.self, UserSettings.self, DividendPayment.self, Contribution.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test func driftIsPositiveWhenOverweight() throws {
        let ctx = try Self.makeContext()
        let h = Holding(ticker: "ITUB3", quantity: 100, currentPrice: 30, assetClass: .acoesBR, status: .aportar, targetPercent: 5)
        ctx.insert(h)
        try? ctx.save()

        let repo = PortfolioRepository(modelContext: ctx)
        let summary = repo.computeSummary(
            holdings: [h],
            classAllocations: [.acoesBR: 20],
            displayCurrency: .brl,
            rates: Self.rates
        )

        let acoesBRAlloc = summary.allocationByClass.first { $0.assetClass == .acoesBR }
        #expect(acoesBRAlloc != nil)
        #expect((acoesBRAlloc?.drift ?? 0) > 0, "Overweight class should have positive drift")
    }

    @Test func computeSummaryAlwaysEmitsAllSixClasses() throws {
        let ctx = try Self.makeContext()
        let repo = PortfolioRepository(modelContext: ctx)
        let summary = repo.computeSummary(
            holdings: [],
            classAllocations: [:],
            displayCurrency: .brl,
            rates: Self.rates
        )

        // The Portfolio tab needs every class to render even with zero holdings
        // and zero targets, so the user can drill into any class to add tickers.
        #expect(summary.allocationByClass.count == AssetClassType.allCases.count)
        for cls in AssetClassType.allCases {
            #expect(summary.allocationByClass.contains { $0.assetClass == cls })
        }
    }

    @Test func saveOnboardingPortfolioPersistsAllSixWeights() throws {
        let ctx = try Self.makeContext()
        let repo = PortfolioRepository(modelContext: ctx)

        let pending = [
            PendingHolding(ticker: "ITUB3", displayName: "Itaú", quantity: 0,
                           assetClass: .acoesBR, status: .estudo,
                           currentPrice: 30, dividendYield: 0)
        ]
        let allocations: [AssetClassType: Decimal] = [
            .acoesBR: 30, .fiis: 25, .usStocks: 15, .reits: 10, .crypto: 5, .rendaFixa: 15
        ]

        _ = try repo.saveOnboardingPortfolio(
            preferredName: "Test",
            nameFallbacks: ["Fallback"],
            pendingHoldings: pending,
            targetAllocations: allocations,
            monthlyIncomeGoal: 0,
            monthlyCostOfLiving: 0
        )

        let settings = try repo.fetchSettings()
        // Even though only acoesBR has holdings, all 6 weights persist so the
        // Settings view reflects what the user set during onboarding.
        #expect(settings.classAllocations.count == AssetClassType.allCases.count)
        #expect(settings.classAllocations[.fiis] == 25)
        #expect(settings.classAllocations[.crypto] == 5)
    }

    @Test func driftIsNegativeWhenUnderweight() throws {
        let ctx = try Self.makeContext()
        let h1 = Holding(ticker: "ITUB3", quantity: 10, currentPrice: 10, assetClass: .acoesBR, status: .aportar, targetPercent: 5)
        let h2 = Holding(ticker: "KNRI11", quantity: 100, currentPrice: 100, assetClass: .fiis, status: .aportar, targetPercent: 5)
        ctx.insert(h1)
        ctx.insert(h2)
        try? ctx.save()

        let repo = PortfolioRepository(modelContext: ctx)
        let summary = repo.computeSummary(
            holdings: [h1, h2],
            classAllocations: [.acoesBR: 80, .fiis: 20],
            displayCurrency: .brl,
            rates: Self.rates
        )

        let acoesBRAlloc = summary.allocationByClass.first { $0.assetClass == .acoesBR }
        #expect(acoesBRAlloc != nil)
        #expect((acoesBRAlloc?.drift ?? 0) < 0, "Underweight class should have negative drift")
    }
}
