import SwiftUI
import GroveDomain

struct GoalSettingsView: View {
    @Bindable var settings: UserSettings
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    var body: some View {
        Form {
            Section {
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
            } footer: {
                Text("Edited in your display currency; stored amounts are FX-converted for display.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Goals")
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            }
        }
        #endif
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
