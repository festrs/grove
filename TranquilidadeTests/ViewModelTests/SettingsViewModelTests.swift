import Testing
import Foundation
import SwiftData
@testable import Tranquilidade

@Suite(.serialized)
struct SettingsViewModelTests {

    // MARK: - Initial state

    @Test func initialState() {
        let vm = SettingsViewModel()
        #expect(vm.settings == nil)
        #expect(vm.holdingCount == 0)
        #expect(vm.portfolioValue == 0)
    }

    // MARK: - loadData

    @MainActor
    @Test func loadDataPopulatesSettings() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = SettingsViewModel()
        vm.loadData(modelContext: ctx)

        #expect(vm.settings != nil)
        #expect(vm.settings!.monthlyIncomeGoal == 8000)
    }

    @MainActor
    @Test func loadDataCountsHoldings() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)

        let vm = SettingsViewModel()
        vm.loadData(modelContext: ctx)

        #expect(vm.holdingCount == holdings.count)
    }

    @MainActor
    @Test func loadDataCalculatesPortfolioValue() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = SettingsViewModel()
        vm.loadData(modelContext: ctx)

        #expect(vm.portfolioValue > 0)
    }

    @MainActor
    @Test func loadDataCreatesSettingsIfMissing() throws {
        let ctx = try makeTestContext()
        // No settings seeded

        let vm = SettingsViewModel()
        vm.loadData(modelContext: ctx)

        #expect(vm.settings != nil)
    }

    // MARK: - resetOnboarding

    @MainActor
    @Test func resetOnboardingSetsFlag() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = SettingsViewModel()
        vm.loadData(modelContext: ctx)
        #expect(vm.settings!.hasCompletedOnboarding == true)

        vm.resetOnboarding()
        #expect(vm.settings!.hasCompletedOnboarding == false)
    }
}
