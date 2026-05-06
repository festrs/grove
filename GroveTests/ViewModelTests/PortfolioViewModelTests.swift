import Testing
import Foundation
import SwiftData
import GroveDomain
import GroveRepositories
@testable import Grove

@Suite(.serialized)
struct PortfolioViewModelTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    // MARK: - Initial state

    @Test func initialState() {
        let vm = PortfolioViewModel()
        #expect(vm.holdings.isEmpty)
        #expect(vm.summary == nil)
        #expect(vm.totalValue.amount == 0)
    }

    // MARK: - loadData

    @MainActor
    @Test func loadDataPopulatesState() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = PortfolioViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(!vm.holdings.isEmpty)
        #expect(vm.summary != nil)
        #expect(vm.totalValue.amount > 0)
        #expect(vm.portfolio != nil)
    }

    // MARK: - deleteHolding

    @MainActor
    @Test func deleteHoldingRemovesFromList() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)

        let vm = PortfolioViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)
        let initialCount = vm.holdings.count

        vm.deleteHolding(holdings[0], modelContext: ctx, displayCurrency: .brl, rates: Self.rates)
        #expect(vm.holdings.count == initialCount - 1)
    }

    // MARK: - Migration

    @MainActor
    @Test func collapseDuplicatePortfoliosMovesHoldingsAndDeletesExtras() throws {
        let ctx = try makeTestContext()
        let oldest = Portfolio(name: "Oldest", createdAt: Date(timeIntervalSince1970: 1_000_000))
        let middle = Portfolio(name: "Middle", createdAt: Date(timeIntervalSince1970: 2_000_000))
        let newest = Portfolio(name: "Newest", createdAt: Date(timeIntervalSince1970: 3_000_000))
        ctx.insert(oldest)
        ctx.insert(middle)
        ctx.insert(newest)

        let h1 = Holding(ticker: "ITUB3", quantity: 10, currentPrice: 30, assetClass: .acoesBR, status: .aportar)
        let h2 = Holding(ticker: "WEGE3", quantity: 5, currentPrice: 40, assetClass: .acoesBR, status: .aportar)
        let h3 = Holding(ticker: "AAPL", quantity: 2, currentPrice: 200, assetClass: .usStocks, status: .aportar)
        ctx.insert(h1); h1.portfolio = oldest
        ctx.insert(h2); h2.portfolio = middle
        ctx.insert(h3); h3.portfolio = newest
        try ctx.save()

        let repo = PortfolioRepository(modelContext: ctx)
        let removed = try repo.collapseDuplicatePortfolios()

        #expect(removed == 2)
        let remaining = try ctx.fetch(FetchDescriptor<Portfolio>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.name == "Oldest")
        #expect(remaining.first?.holdings.count == 3)
    }

    @MainActor
    @Test func collapseDuplicatePortfoliosIsNoOpForSinglePortfolio() throws {
        let ctx = try makeTestContext()
        let only = Portfolio(name: "Only")
        ctx.insert(only)
        try ctx.save()

        let repo = PortfolioRepository(modelContext: ctx)
        let removed = try repo.collapseDuplicatePortfolios()

        #expect(removed == 0)
        #expect(try ctx.fetch(FetchDescriptor<Portfolio>()).count == 1)
    }

    // MARK: - allocationByClass

    @MainActor
    @Test func allocationByClassPopulated() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = PortfolioViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(!vm.allocationByClass.isEmpty)
    }

    // MARK: - Drift direction

    @MainActor
    @Test func driftIsPositiveWhenOverweight() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Drift Test")
        ctx.insert(portfolio)
        portfolio.classAllocations = [.acoesBR: 20]

        let h = Holding(ticker: "ITUB3", quantity: 100, currentPrice: 30, assetClass: .acoesBR, status: .aportar, targetPercent: 5)
        ctx.insert(h)
        h.portfolio = portfolio
        try? ctx.save()

        let repo = PortfolioRepository(modelContext: ctx)
        let summary = repo.computeSummary(
            holdings: [h],
            classAllocations: portfolio.classAllocations,
            displayCurrency: .brl,
            rates: Self.rates
        )

        let acoesBRAlloc = summary.allocationByClass.first { $0.assetClass == .acoesBR }
        #expect(acoesBRAlloc != nil)
        #expect((acoesBRAlloc?.drift ?? 0) > 0, "Overweight class should have positive drift")
    }

    @MainActor
    @Test func driftIsNegativeWhenUnderweight() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Drift Test 2")
        ctx.insert(portfolio)
        portfolio.classAllocations = [.acoesBR: 80, .fiis: 20]

        let h1 = Holding(ticker: "ITUB3", quantity: 10, currentPrice: 10, assetClass: .acoesBR, status: .aportar, targetPercent: 5)
        let h2 = Holding(ticker: "KNRI11", quantity: 100, currentPrice: 100, assetClass: .fiis, status: .aportar, targetPercent: 5)
        ctx.insert(h1)
        ctx.insert(h2)
        h1.portfolio = portfolio
        h2.portfolio = portfolio
        try? ctx.save()

        let repo = PortfolioRepository(modelContext: ctx)
        let summary = repo.computeSummary(
            holdings: [h1, h2],
            classAllocations: portfolio.classAllocations,
            displayCurrency: .brl,
            rates: Self.rates
        )

        let acoesBRAlloc = summary.allocationByClass.first { $0.assetClass == .acoesBR }
        #expect(acoesBRAlloc != nil)
        #expect((acoesBRAlloc?.drift ?? 0) < 0, "Underweight class should have negative drift")
    }
}
