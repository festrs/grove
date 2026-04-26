import Testing
import Foundation
import SwiftData
@testable import Grove

@Suite(.serialized)
struct DashboardViewModelTests {

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
        vm.loadData(modelContext: ctx)

        #expect(vm.summary != nil)
        #expect(vm.summary!.totalValue > 0)
    }

    @MainActor
    @Test func loadDataPopulatesProjection() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = DashboardViewModel()
        vm.loadData(modelContext: ctx)

        #expect(vm.projection != nil)
        #expect(vm.projection!.goalMonthly == 8000) // from seeded settings
    }

    @MainActor
    @Test func loadDataPopulatesSuggestions() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = DashboardViewModel()
        vm.loadData(modelContext: ctx)

        #expect(!vm.topSuggestions.isEmpty)
    }

    @MainActor
    @Test func loadDataWithEmptyPortfolio() throws {
        let ctx = try makeTestContext()
        // Only insert settings, no holdings
        let settings = UserSettings(monthlyIncomeGoal: 5000, hasCompletedOnboarding: true)
        ctx.insert(settings)

        let vm = DashboardViewModel()
        vm.loadData(modelContext: ctx)

        #expect(vm.summary != nil)
        #expect(vm.summary!.totalValue == 0)
        #expect(vm.topSuggestions.isEmpty)
    }

    @MainActor
    @Test func loadDataSetsLoadingFalseOnCompletion() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = DashboardViewModel()
        vm.loadData(modelContext: ctx)

        #expect(vm.isLoading == false)
    }
}
