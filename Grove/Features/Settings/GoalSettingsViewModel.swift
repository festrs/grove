import Foundation
import SwiftData
import GroveDomain
import GroveServices

/// Backs `GoalSettingsView`. Owns the live Freedom Number readout and the
/// display-currency ↔ stored-currency bridge for every editable amount on
/// the Goals form.
@Observable
@MainActor
final class GoalSettingsViewModel {
    private(set) var settings: UserSettings?
    var displayCurrency: Currency = .brl
    var rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    /// Range of years offered in the FI year picker.
    var fiYearRange: ClosedRange<Int> {
        let now = Calendar.current.component(.year, from: .now)
        return now...(now + 50)
    }

    func bind(settings: UserSettings, displayCurrency: Currency, rates: any ExchangeRates) {
        self.settings = settings
        self.displayCurrency = displayCurrency
        self.rates = rates
    }

    /// Per-asset-class net monthly income (paid + projected, post-tax) for the
    /// current calendar month. Powers the gauge explainer on the Goals screen
    /// so users can see what makes up the number in the middle of the ring.
    /// Sorted descending by net amount; classes with zero income are dropped.
    func monthlyNetByClass(holdings: [Holding]) -> MoneyTaxBreakdown {
        let perClass = IncomeAggregator.byClass(
            holdings: holdings,
            window: .month,
            in: displayCurrency,
            rates: rates
        )
        var grossByClass: [AssetClassType: Money] = [:]
        for row in perClass {
            grossByClass[row.assetClass] = row.total
        }
        return TaxCalculator.taxBreakdown(
            grossByClass: grossByClass,
            displayCurrency: displayCurrency,
            rates: rates
        )
    }

    /// Live Freedom Number for the current settings, expressed in display currency.
    var freedomNumber: Money {
        guard let s = settings else { return Money(amount: 0, currency: displayCurrency) }
        return FreedomPlanCalculator.freedomNumber(
            monthlyCostOfLiving: s.monthlyCostOfLivingMoney,
            incomeMode: s.fiIncomeMode,
            currencyMixBRLPercent: s.fiCurrencyMixBRLPercent,
            displayCurrency: displayCurrency,
            rates: rates
        ).total
    }

    /// Sync the persisted income goal with the current Freedom Number, e.g.
    /// after the user edits cost-of-living or income mode in Settings. Keeps
    /// the Dashboard gauge truthful without a separate "save" action.
    func syncIncomeGoalToFreedomNumber() {
        guard let s = settings else { return }
        s.monthlyIncomeGoalMoney = freedomNumber
    }

    func decimalBinding(
        for amount: ReferenceWritableKeyPath<UserSettings, Decimal>,
        currency: ReferenceWritableKeyPath<UserSettings, Currency>
    ) -> (get: () -> Decimal, set: (Decimal) -> Void) {
        let getter: () -> Decimal = { [weak self] in
            guard let self, let s = self.settings else { return 0 }
            let stored = Money(amount: s[keyPath: amount], currency: s[keyPath: currency])
            return stored.converted(to: self.displayCurrency, using: self.rates).amount
        }
        let setter: (Decimal) -> Void = { [weak self] newValue in
            guard let self, let s = self.settings else { return }
            s[keyPath: amount] = newValue
            s[keyPath: currency] = self.displayCurrency
            self.syncIncomeGoalToFreedomNumber()
        }
        return (getter, setter)
    }

    /// Mode picker setter: persist + recompute multiplier + sync goal.
    func setIncomeMode(_ mode: FIIncomeMode) {
        guard let s = settings else { return }
        s.fiIncomeMode = mode
        s.costAtFIMultiplier = mode.multiplier
        syncIncomeGoalToFreedomNumber()
    }

    func setTargetFIYear(_ year: Int) {
        settings?.targetFIYear = year
    }

    func setCurrencyMixBRLPercent(_ percent: Decimal) {
        guard let s = settings else { return }
        s.fiCurrencyMixBRLPercent = max(0, min(100, percent))
        syncIncomeGoalToFreedomNumber()
    }

    /// Mark the Freedom Plan as authored — used after the user reviews and
    /// edits an existing plan, so the Dashboard nudge banner goes away.
    func markPlanCompleted() {
        if settings?.freedomPlanCompletedAt == nil {
            settings?.freedomPlanCompletedAt = .now
        }
    }
}
