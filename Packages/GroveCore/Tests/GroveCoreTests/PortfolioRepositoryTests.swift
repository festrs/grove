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
