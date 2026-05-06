import Testing
import Foundation
@testable import GroveDomain

@MainActor
struct UserSettingsFreedomPlanTests {

    @Test func defaultsAreUnsetForFreedomPlan() {
        let s = UserSettings()
        #expect(s.targetFIYear == 0)
        #expect(s.fiIncomeMode == .essentials)
        #expect(s.costAtFIMultiplier == 1.0)
        #expect(s.monthlyContributionCapacity == 0)
        #expect(s.fiCurrencyMixBRLPercent == 100)
        #expect(s.freedomPlanCompletedAt == nil)
        #expect(s.monthlyIncomeGoal == 0,
                "Income goal default must be 0 — the Freedom Plan derives it.")
    }

    @Test func incomeModeRoundTripsThroughRawString() {
        let s = UserSettings()
        s.fiIncomeMode = .lifestylePlusBuffer
        #expect(s.fiIncomeModeRaw == "lifestyle_plus_buffer")
        #expect(s.fiIncomeMode == .lifestylePlusBuffer)
    }

    @Test func incomeModeMultipliers() {
        #expect(FIIncomeMode.essentials.multiplier == 1.0)
        #expect(FIIncomeMode.lifestyle.multiplier == 1.5)
        #expect(FIIncomeMode.lifestylePlusBuffer.multiplier == 2.0)
    }

    @Test func costAtFIMoneyAppliesMultiplier() {
        let s = UserSettings()
        s.monthlyCostOfLiving = 10_000
        s.monthlyCostOfLivingCurrencyRaw = Currency.brl.rawValue
        s.costAtFIMultiplier = 1.5

        let cost = s.costAtFIMoney
        #expect(cost.amount == 15_000)
        #expect(cost.currency == .brl)
    }

    @Test func costAtFIMoneyUsesCostCurrency() {
        let s = UserSettings()
        s.monthlyCostOfLiving = 5_000
        s.monthlyCostOfLivingCurrencyRaw = Currency.usd.rawValue
        s.costAtFIMultiplier = 2.0

        let cost = s.costAtFIMoney
        #expect(cost.amount == 10_000)
        #expect(cost.currency == .usd,
                "costAtFIMoney must inherit the cost-of-living currency, not preferredCurrency")
    }

    @Test func monthlyContributionCapacityMoneyRoundTrip() {
        let s = UserSettings()
        s.monthlyContributionCapacityMoney = Money(amount: 3_500, currency: .usd)
        #expect(s.monthlyContributionCapacity == 3_500)
        #expect(s.monthlyContributionCapacityCurrency == .usd)
        #expect(s.monthlyContributionCapacityMoney.amount == 3_500)
        #expect(s.monthlyContributionCapacityMoney.currency == .usd)
    }

    @Test func fiIncomeModeFallsBackToEssentialsForBadRaw() {
        let s = UserSettings()
        s.fiIncomeModeRaw = "garbage"
        #expect(s.fiIncomeMode == .essentials)
    }

    @Test func freedomPlanCompletedAtRoundTrip() {
        let s = UserSettings()
        let now = Date()
        s.freedomPlanCompletedAt = now
        #expect(s.freedomPlanCompletedAt == now)
    }
}
