import Testing
import Foundation
import SwiftData
import GroveDomain
import GroveServices
@testable import Grove

@MainActor
struct GoalSettingsViewModelTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    private static func makeContext() throws -> ModelContext {
        let schema = Schema([
            Portfolio.self, Holding.self, UserSettings.self,
            DividendPayment.self, Transaction.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test func freedomNumberIsCostTimesMultiplier() throws {
        let ctx = try Self.makeContext()
        let s = UserSettings()
        s.monthlyCostOfLiving = 8_000
        s.monthlyCostOfLivingCurrencyRaw = Currency.brl.rawValue
        s.fiIncomeMode = .lifestyle
        ctx.insert(s)

        let vm = GoalSettingsViewModel()
        vm.bind(settings: s, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.freedomNumber.amount == 12_000)
        #expect(vm.freedomNumber.currency == .brl)
    }

    @Test func setIncomeModeUpdatesGoalAndMultiplier() throws {
        let ctx = try Self.makeContext()
        let s = UserSettings()
        s.monthlyCostOfLiving = 5_000
        s.monthlyCostOfLivingCurrencyRaw = Currency.brl.rawValue
        ctx.insert(s)

        let vm = GoalSettingsViewModel()
        vm.bind(settings: s, displayCurrency: .brl, rates: Self.rates)
        vm.setIncomeMode(.lifestylePlusBuffer)

        #expect(s.fiIncomeMode == .lifestylePlusBuffer)
        #expect(s.costAtFIMultiplier == 2.0)
        #expect(s.monthlyIncomeGoal == 10_000,
                "Income goal must auto-sync to the new Freedom Number after a mode change.")
    }

    @Test func decimalBindingPersistsInDisplayCurrency() throws {
        let ctx = try Self.makeContext()
        let s = UserSettings()
        ctx.insert(s)

        let vm = GoalSettingsViewModel()
        vm.bind(settings: s, displayCurrency: .usd, rates: Self.rates)
        let binding = vm.decimalBinding(
            for: \.monthlyCostOfLiving,
            currency: \.monthlyCostOfLivingCurrency
        )
        binding.set(2_000) // in USD

        #expect(s.monthlyCostOfLiving == 2_000)
        #expect(s.monthlyCostOfLivingCurrency == .usd)
    }

    @Test func setCurrencyMixClampsToZeroToHundred() throws {
        let ctx = try Self.makeContext()
        let s = UserSettings()
        ctx.insert(s)
        let vm = GoalSettingsViewModel()
        vm.bind(settings: s, displayCurrency: .brl, rates: Self.rates)

        vm.setCurrencyMixBRLPercent(150)
        #expect(s.fiCurrencyMixBRLPercent == 100)

        vm.setCurrencyMixBRLPercent(-10)
        #expect(s.fiCurrencyMixBRLPercent == 0)
    }

    @Test func markPlanCompletedSetsTimestampOnce() throws {
        let ctx = try Self.makeContext()
        let s = UserSettings()
        ctx.insert(s)
        let vm = GoalSettingsViewModel()
        vm.bind(settings: s, displayCurrency: .brl, rates: Self.rates)

        #expect(s.freedomPlanCompletedAt == nil)
        vm.markPlanCompleted()
        let firstStamp = s.freedomPlanCompletedAt
        #expect(firstStamp != nil)

        vm.markPlanCompleted()
        #expect(s.freedomPlanCompletedAt == firstStamp,
                "Subsequent calls must not overwrite the original completion timestamp.")
    }

    @Test func fiYearRangeStartsAtCurrentYear() {
        let vm = GoalSettingsViewModel()
        let now = Calendar.current.component(.year, from: .now)
        #expect(vm.fiYearRange.lowerBound == now)
        #expect(vm.fiYearRange.upperBound == now + 50)
    }
}
