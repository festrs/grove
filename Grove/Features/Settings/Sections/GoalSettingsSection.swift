import SwiftUI

struct GoalSettingsSection: View {
    @Bindable var settings: UserSettings
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    var body: some View {
        Section("Goals") {
            TQCurrencyField(
                title: "Monthly Passive Income",
                currency: displayCurrency,
                value: binding(for: \.monthlyIncomeGoal, currency: \.monthlyIncomeGoalCurrency)
            )

            TQCurrencyField(
                title: "Monthly Cost of Living",
                currency: displayCurrency,
                value: binding(for: \.monthlyCostOfLiving, currency: \.monthlyCostOfLivingCurrency)
            )

            TQCurrencyField(
                title: "Emergency Reserve (Target)",
                currency: displayCurrency,
                value: binding(for: \.emergencyReserveTarget, currency: \.emergencyReserveTargetCurrency)
            )

            TQCurrencyField(
                title: "Emergency Reserve (Current)",
                currency: displayCurrency,
                value: binding(for: \.emergencyReserveCurrent, currency: \.emergencyReserveCurrentCurrency)
            )
        }

        // Goal fields always edit in the user's chosen displayCurrency.
        // The stored amount is converted via FX for display, and on edit we
        // overwrite both amount and per-field currency in displayCurrency.
        // This keeps the symbol next to the value consistent with the rest of the app.

        Section("Rebalancing") {
            Stepper(
                "Recommendations per investment: \(settings.recommendationCount)",
                value: $settings.recommendationCount,
                in: 1...10
            )
        }
    }

    private func binding(
        for amount: ReferenceWritableKeyPath<UserSettings, Decimal>,
        currency: ReferenceWritableKeyPath<UserSettings, Currency>
    ) -> Binding<Decimal> {
        Binding<Decimal>(
            get: {
                let stored = Money(amount: settings[keyPath: amount], currency: settings[keyPath: currency])
                return stored.converted(to: displayCurrency, using: rates).amount
            },
            set: { newValue in
                settings[keyPath: amount] = newValue
                settings[keyPath: currency] = displayCurrency
            }
        )
    }
}
