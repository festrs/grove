import Testing
import Foundation
import SwiftData
@testable import Grove

@Suite(.serialized)
struct PortfolioViewModelTests {

    // MARK: - Initial state

    @Test func initialState() {
        let vm = PortfolioViewModel()
        #expect(vm.selectedClass == nil)
        #expect(vm.holdings.isEmpty)
        #expect(vm.filteredHoldings.isEmpty)
        #expect(vm.summary == nil)
        #expect(vm.totalValue == 0)
    }

    // MARK: - loadData

    @MainActor
    @Test func loadDataPopulatesState() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = PortfolioViewModel()
        vm.loadData(modelContext: ctx)

        #expect(!vm.holdings.isEmpty)
        #expect(!vm.filteredHoldings.isEmpty)
        #expect(vm.summary != nil)
        #expect(vm.totalValue > 0)
        #expect(!vm.portfolios.isEmpty)
        #expect(vm.selectedPortfolio != nil)
    }

    // MARK: - selectClass / applyFilter

    @MainActor
    @Test func selectClassFiltersHoldings() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = PortfolioViewModel()
        vm.loadData(modelContext: ctx)

        vm.selectClass(.acoesBR)
        #expect(vm.selectedClass == .acoesBR)
        #expect(vm.filteredHoldings.allSatisfy { $0.assetClass == .acoesBR })
    }

    @MainActor
    @Test func selectClassNilShowsAll() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = PortfolioViewModel()
        vm.loadData(modelContext: ctx)

        vm.selectClass(.acoesBR)
        let filteredCount = vm.filteredHoldings.count

        vm.selectClass(nil)
        #expect(vm.filteredHoldings.count > filteredCount)
    }

    @MainActor
    @Test func selectClassWithNoMatchReturnsEmpty() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = PortfolioViewModel()
        vm.loadData(modelContext: ctx)

        vm.selectClass(.crypto)
        #expect(vm.filteredHoldings.isEmpty)
    }

    // MARK: - deleteHolding

    @MainActor
    @Test func deleteHoldingRemovesFromList() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)

        let vm = PortfolioViewModel()
        vm.loadData(modelContext: ctx)
        let initialCount = vm.holdings.count

        vm.deleteHolding(holdings[0], modelContext: ctx)
        #expect(vm.holdings.count == initialCount - 1)
    }

    // MARK: - createPortfolio

    @MainActor
    @Test func createPortfolioAddsAndSelects() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = PortfolioViewModel()
        vm.loadData(modelContext: ctx)
        let initialCount = vm.portfolios.count

        vm.createPortfolio(name: "New Portfolio", modelContext: ctx)
        #expect(vm.portfolios.count == initialCount + 1)
        #expect(vm.selectedPortfolio?.name == "New Portfolio")
    }

    // MARK: - allocationByClass

    @MainActor
    @Test func allocationByClassPopulated() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = PortfolioViewModel()
        vm.loadData(modelContext: ctx)

        #expect(!vm.allocationByClass.isEmpty)
    }

    // MARK: - Drift direction

    @MainActor
    @Test func driftIsPositiveWhenOverweight() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Drift Test")
        ctx.insert(portfolio)
        // Target 20% for acoesBR, but it's the only class → 100% current
        portfolio.classAllocations = [.acoesBR: 20]

        let h = Holding(ticker: "ITUB3", quantity: 100, currentPrice: 30, assetClass: .acoesBR, status: .aportar, targetPercent: 5)
        ctx.insert(h)
        h.portfolio = portfolio
        try? ctx.save()

        let repo = PortfolioRepository(modelContext: ctx)
        let summary = repo.computeSummary(holdings: [h], classAllocations: portfolio.classAllocations)

        let acoesBRAlloc = summary.allocationByClass.first { $0.assetClass == .acoesBR }
        #expect(acoesBRAlloc != nil)
        #expect(acoesBRAlloc!.drift > 0, "Overweight class should have positive drift")
    }

    @MainActor
    @Test func driftIsNegativeWhenUnderweight() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Drift Test 2")
        ctx.insert(portfolio)
        // Target 80% for acoesBR, but fiis has more value → acoesBR underweight
        portfolio.classAllocations = [.acoesBR: 80, .fiis: 20]

        let h1 = Holding(ticker: "ITUB3", quantity: 10, currentPrice: 10, assetClass: .acoesBR, status: .aportar, targetPercent: 5)
        let h2 = Holding(ticker: "KNRI11", quantity: 100, currentPrice: 100, assetClass: .fiis, status: .aportar, targetPercent: 5)
        ctx.insert(h1)
        ctx.insert(h2)
        h1.portfolio = portfolio
        h2.portfolio = portfolio
        try? ctx.save()

        let repo = PortfolioRepository(modelContext: ctx)
        let summary = repo.computeSummary(holdings: [h1, h2], classAllocations: portfolio.classAllocations)

        let acoesBRAlloc = summary.allocationByClass.first { $0.assetClass == .acoesBR }
        #expect(acoesBRAlloc != nil)
        #expect(acoesBRAlloc!.drift < 0, "Underweight class should have negative drift")
    }
}
