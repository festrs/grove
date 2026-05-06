import Testing
import Foundation
@testable import GroveDomain
@testable import GroveServices

@MainActor
struct FreedomPlanCalculatorTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    @Test func essentialsModeReturnsCostOneToOne() {
        let cost = Money(amount: 10_000, currency: .brl)
        let result = FreedomPlanCalculator.freedomNumber(
            monthlyCostOfLiving: cost,
            incomeMode: .essentials,
            currencyMixBRLPercent: 100,
            displayCurrency: .brl,
            rates: Self.rates
        )
        #expect(result.total.amount == 10_000)
        #expect(result.total.currency == .brl)
    }

    @Test func lifestyleModeApplies1_5xMultiplier() {
        let cost = Money(amount: 10_000, currency: .brl)
        let result = FreedomPlanCalculator.freedomNumber(
            monthlyCostOfLiving: cost,
            incomeMode: .lifestyle,
            currencyMixBRLPercent: 100,
            displayCurrency: .brl,
            rates: Self.rates
        )
        #expect(result.total.amount == 15_000)
    }

    @Test func lifestylePlusBufferModeApplies2xMultiplier() {
        let cost = Money(amount: 10_000, currency: .brl)
        let result = FreedomPlanCalculator.freedomNumber(
            monthlyCostOfLiving: cost,
            incomeMode: .lifestylePlusBuffer,
            currencyMixBRLPercent: 100,
            displayCurrency: .brl,
            rates: Self.rates
        )
        #expect(result.total.amount == 20_000)
    }

    @Test func currencyMixSplitsTotalProportionally() {
        let cost = Money(amount: 10_000, currency: .brl)
        let result = FreedomPlanCalculator.freedomNumber(
            monthlyCostOfLiving: cost,
            incomeMode: .essentials,
            currencyMixBRLPercent: 70,
            displayCurrency: .brl,
            rates: Self.rates
        )
        #expect(result.total.amount == 10_000)
        #expect(result.brlSlice.amount == 7_000)
        #expect(result.usdSlice.amount == 3_000)
    }

    @Test func currencyMixClampsAbove100() {
        let cost = Money(amount: 10_000, currency: .brl)
        let result = FreedomPlanCalculator.freedomNumber(
            monthlyCostOfLiving: cost,
            incomeMode: .essentials,
            currencyMixBRLPercent: 150,
            displayCurrency: .brl,
            rates: Self.rates
        )
        #expect(result.brlSlice.amount == 10_000)
        #expect(result.usdSlice.amount == 0)
    }

    @Test func currencyMixClampsBelowZero() {
        let cost = Money(amount: 10_000, currency: .brl)
        let result = FreedomPlanCalculator.freedomNumber(
            monthlyCostOfLiving: cost,
            incomeMode: .essentials,
            currencyMixBRLPercent: -25,
            displayCurrency: .brl,
            rates: Self.rates
        )
        #expect(result.brlSlice.amount == 0)
        #expect(result.usdSlice.amount == 10_000)
    }

    @Test func costInUsdConvertsToDisplayCurrency() {
        // 2,000 USD cost × 5 BRL/USD = 10,000 BRL × 1.5 = 15,000 BRL
        let cost = Money(amount: 2_000, currency: .usd)
        let result = FreedomPlanCalculator.freedomNumber(
            monthlyCostOfLiving: cost,
            incomeMode: .lifestyle,
            currencyMixBRLPercent: 100,
            displayCurrency: .brl,
            rates: Self.rates
        )
        #expect(result.total.amount == 15_000)
        #expect(result.total.currency == .brl)
    }

    @Test func zeroCostReturnsZero() {
        let cost = Money(amount: 0, currency: .brl)
        let result = FreedomPlanCalculator.freedomNumber(
            monthlyCostOfLiving: cost,
            incomeMode: .lifestylePlusBuffer,
            currencyMixBRLPercent: 50,
            displayCurrency: .brl,
            rates: Self.rates
        )
        #expect(result.total.amount == 0)
        #expect(result.brlSlice.amount == 0)
        #expect(result.usdSlice.amount == 0)
    }
}
