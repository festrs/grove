import Foundation
import GroveDomain

/// Derives the user's "Freedom Number" — the target net monthly passive income
/// needed to be financially independent — from the lifestyle inputs collected
/// during the Freedom Plan onboarding step.
///
/// Currency mix is informational in v1: it shapes the copy on the reveal
/// screen ("≈ R$X from BR + ≈ R$Y from US") but does not change the number
/// itself. The result is always expressed in `displayCurrency`.
public enum FreedomPlanCalculator {

    public struct Breakdown: Sendable, Equatable {
        public let total: Money
        /// Slice of `total` expected to come from BRL-denominated assets.
        public let brlSlice: Money
        /// Slice of `total` expected to come from non-BRL (USD) assets,
        /// expressed in `displayCurrency`.
        public let usdSlice: Money

        public init(total: Money, brlSlice: Money, usdSlice: Money) {
            self.total = total
            self.brlSlice = brlSlice
            self.usdSlice = usdSlice
        }
    }

    /// Compute the Freedom Number.
    /// - Parameters:
    ///   - monthlyCostOfLiving: cost of living **today**.
    ///   - incomeMode: lifestyle mode (essentials/lifestyle/+buffer) — applies a multiplier.
    ///   - currencyMixBRLPercent: 0–100. Percentage of FI income expected from BRL assets.
    ///   - displayCurrency: currency to express the result in.
    ///   - rates: FX rates for converting cost-of-living into `displayCurrency`.
    public static func freedomNumber(
        monthlyCostOfLiving: Money,
        incomeMode: FIIncomeMode,
        currencyMixBRLPercent: Decimal,
        displayCurrency: Currency,
        rates: any ExchangeRates
    ) -> Breakdown {
        let costInDisplay = monthlyCostOfLiving.converted(to: displayCurrency, using: rates)
        let total = Money(
            amount: costInDisplay.amount * incomeMode.multiplier,
            currency: displayCurrency
        )
        let mix = clamp01(currencyMixBRLPercent / 100)
        let brl = Money(amount: total.amount * mix, currency: displayCurrency)
        let usd = Money(amount: total.amount - brl.amount, currency: displayCurrency)
        return Breakdown(total: total, brlSlice: brl, usdSlice: usd)
    }

    private static func clamp01(_ value: Decimal) -> Decimal {
        if value < 0 { return 0 }
        if value > 1 { return 1 }
        return value
    }
}
