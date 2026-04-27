import Testing
import Foundation
import SwiftData
import GroveDomain
import GroveServices
import GroveRepositories
@testable import Grove

@Suite(.serialized)
struct DashboardViewModelTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    // MARK: - Initial state

    @Test func initialState() {
        let vm = DashboardViewModel()
        #expect(vm.summary == nil)
        #expect(vm.projection == nil)
        #expect(vm.topSuggestions.isEmpty)
        #expect(vm.nextDividends.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    // MARK: - loadData

    @MainActor
    @Test func loadDataPopulatesSummary() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = DashboardViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.summary != nil)
        #expect(vm.summary!.totalValue.amount > 0)
        #expect(vm.summary!.totalValue.currency == .brl)
    }

    @MainActor
    @Test func loadDataPopulatesProjection() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = DashboardViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.projection != nil)
        #expect(vm.projection!.goalMonthly.amount == 8000)
    }

    @MainActor
    @Test func loadDataPopulatesSuggestions() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = DashboardViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(!vm.topSuggestions.isEmpty)
    }

    @MainActor
    @Test func loadDataWithEmptyPortfolio() throws {
        let ctx = try makeTestContext()
        let settings = UserSettings(monthlyIncomeGoal: 5000, hasCompletedOnboarding: true)
        ctx.insert(settings)

        let vm = DashboardViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.summary != nil)
        #expect(vm.summary!.totalValue.amount == 0)
        #expect(vm.topSuggestions.isEmpty)
    }

    @MainActor
    @Test func loadDataSetsLoadingFalseOnCompletion() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = DashboardViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.isLoading == false)
    }
}
