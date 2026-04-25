import Testing
import Foundation
import SwiftData
@testable import Grove

@Suite(.serialized)
struct IncomeHistoryViewModelTests {

    // MARK: - Initial state

    @Test func initialState() {
        let vm = IncomeHistoryViewModel()
        #expect(vm.incomeByClass.isEmpty)
        #expect(vm.totalAnnualBRL == 0)
        #expect(vm.monthlyIncomeBRL == 0)
        #expect(vm.taxBreakdown == nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - loadData

    @MainActor
    @Test func loadDataPopulatesIncome() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx)

        #expect(!vm.incomeByClass.isEmpty)
        #expect(vm.totalAnnualBRL > 0)
        #expect(vm.monthlyIncomeBRL > 0)
        #expect(vm.monthlyIncomeBRL == vm.totalAnnualBRL / 12)
    }

    @MainActor
    @Test func loadDataPopulatesTaxBreakdown() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx)

        #expect(vm.taxBreakdown != nil)
        #expect(vm.taxBreakdown!.totalNet > 0)
    }

    @MainActor
    @Test func loadDataSortsByAnnualDescending() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx)

        let annuals = vm.incomeByClass.map(\.annual)
        for i in 0..<annuals.count - 1 {
            #expect(annuals[i] >= annuals[i + 1])
        }
    }

    @MainActor
    @Test func loadDataWithEmptyPortfolio() throws {
        let ctx = try makeTestContext()

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx)

        #expect(vm.incomeByClass.isEmpty)
        #expect(vm.totalAnnualBRL == 0)
    }

    @MainActor
    @Test func loadDataSetsLoadingFalse() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx)

        #expect(vm.isLoading == false)
    }
}
