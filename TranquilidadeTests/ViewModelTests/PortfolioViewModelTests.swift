import Testing
import Foundation
import SwiftData
@testable import Tranquilidade

struct PortfolioViewModelTests {

    // MARK: - Initial state

    @Test func initialState() {
        let vm = PortfolioViewModel()
        #expect(vm.selectedClass == nil)
        #expect(vm.holdings.isEmpty)
        #expect(vm.filteredHoldings.isEmpty)
        #expect(vm.summary == nil)
        #expect(vm.totalValueBRL == 0)
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
        #expect(vm.totalValueBRL > 0)
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
}
