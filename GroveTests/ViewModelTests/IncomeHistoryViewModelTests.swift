import Testing
import Foundation
import SwiftData
@testable import Grove

@Suite(.serialized)
struct IncomeHistoryViewModelTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    // MARK: - Initial state

    @Test func initialState() {
        let vm = IncomeHistoryViewModel()
        #expect(vm.incomeByClass.isEmpty)
        #expect(vm.totalAnnual.amount == 0)
        #expect(vm.monthlyIncome.amount == 0)
        #expect(vm.taxBreakdown == nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - loadData

    @MainActor
    @Test func loadDataPopulatesIncome() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(!vm.incomeByClass.isEmpty)
        #expect(vm.totalAnnual.amount > 0)
        #expect(vm.monthlyIncome.amount > 0)
        #expect(vm.monthlyIncome.amount == vm.totalAnnual.amount / 12)
    }

    @MainActor
    @Test func loadDataPopulatesTaxBreakdown() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.taxBreakdown != nil)
        #expect(vm.taxBreakdown!.totalNet.amount > 0)
    }

    @MainActor
    @Test func loadDataSortsByAnnualDescending() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        for i in 0..<vm.incomeByClass.count - 1 {
            let lhs = vm.incomeByClass[i].annual.converted(to: .brl, using: Self.rates).amount
            let rhs = vm.incomeByClass[i + 1].annual.converted(to: .brl, using: Self.rates).amount
            #expect(lhs >= rhs)
        }
    }

    @MainActor
    @Test func loadDataWithEmptyPortfolio() throws {
        let ctx = try makeTestContext()

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.incomeByClass.isEmpty)
        #expect(vm.totalAnnual.amount == 0)
    }

    @MainActor
    @Test func loadDataSetsLoadingFalse() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.isLoading == false)
    }
}
