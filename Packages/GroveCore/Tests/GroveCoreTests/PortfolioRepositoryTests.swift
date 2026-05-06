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

    // MARK: - Holding.currentPercent (allocation math used by views)

    @Test func currentPercentReturnsHoldingShareOfTotal() {
        let h = Holding(ticker: "ITUB3", quantity: 10, currentPrice: 100,
                        assetClass: .acoesBR, status: .aportar)
        // currentValue = 1000 BRL, totalValue = 4000 BRL → 25%.
        // If the empty-guard is inverted, this returns 0 instead of 25.
        let pct = h.currentPercent(
            of: Money(amount: 4000, currency: .brl),
            in: .brl, rates: Self.rates
        )
        #expect(pct == 25)
    }

    @Test func currentPercentReturnsZeroForEmptyPortfolio() {
        let h = Holding(ticker: "ITUB3", quantity: 10, currentPrice: 100,
                        assetClass: .acoesBR, status: .aportar)
        let pct = h.currentPercent(
            of: Money(amount: 0, currency: .brl),
            in: .brl, rates: Self.rates
        )
        #expect(pct == 0)
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

        let plan = PortfolioRepository.FreedomPlanInput(
            monthlyCostOfLiving: 8_000,
            costOfLivingCurrency: .brl,
            targetFIYear: 2046,
            incomeMode: .lifestyle,
            monthlyContributionCapacity: 3_000,
            contributionCurrency: .brl,
            currencyMixBRLPercent: 70,
            freedomNumber: Money(amount: 12_000, currency: .brl)
        )
        _ = try repo.saveOnboardingPortfolio(
            preferredName: "Test",
            nameFallbacks: ["Fallback"],
            pendingHoldings: pending,
            targetAllocations: allocations,
            freedomPlan: plan
        )

        let settings = try repo.fetchSettings()
        // Even though only acoesBR has holdings, all 6 weights persist so the
        // Settings view reflects what the user set during onboarding.
        #expect(settings.classAllocations.count == AssetClassType.allCases.count)
        #expect(settings.classAllocations[.fiis] == 25)
        #expect(settings.classAllocations[.crypto] == 5)
    }

    @Test func saveOnboardingPortfolioPersistsFreedomPlan() throws {
        let ctx = try Self.makeContext()
        let repo = PortfolioRepository(modelContext: ctx)

        let plan = PortfolioRepository.FreedomPlanInput(
            monthlyCostOfLiving: 6_000,
            costOfLivingCurrency: .brl,
            targetFIYear: 2050,
            incomeMode: .lifestylePlusBuffer,
            monthlyContributionCapacity: 4_500,
            contributionCurrency: .brl,
            currencyMixBRLPercent: 60,
            freedomNumber: Money(amount: 12_000, currency: .brl)
        )
        _ = try repo.saveOnboardingPortfolio(
            preferredName: "Plan Test",
            nameFallbacks: ["Plan Fallback"],
            pendingHoldings: [],
            targetAllocations: [.acoesBR: 100],
            freedomPlan: plan
        )

        let settings = try repo.fetchSettings()
        #expect(settings.monthlyIncomeGoal == 12_000)
        #expect(settings.targetFIYear == 2050)
        #expect(settings.fiIncomeMode == .lifestylePlusBuffer)
        #expect(settings.costAtFIMultiplier == 2.0)
        #expect(settings.monthlyContributionCapacity == 4_500)
        #expect(settings.fiCurrencyMixBRLPercent == 60)
        #expect(settings.freedomPlanCompletedAt != nil,
                "completedAt must be stamped so the dashboard nudge banner stays hidden after onboarding.")
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
