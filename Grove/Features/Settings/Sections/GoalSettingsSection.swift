import SwiftUI

struct GoalSettingsSection: View {
    @Bindable var settings: UserSettings
    @Environment(\.displayCurrency) private var displayCurrency

    var body: some View {
        Section("Goals") {
            TQCurrencyField(
                title: "Monthly Passive Income",
                currency: settings.monthlyIncomeGoalCurrency,
                value: $settings.monthlyIncomeGoal
            )
            .onChange(of: settings.monthlyIncomeGoal) { _, _ in
                settings.monthlyIncomeGoalCurrency = displayCurrency
            }

            TQCurrencyField(
                title: "Monthly Cost of Living",
                currency: settings.monthlyCostOfLivingCurrency,
                value: $settings.monthlyCostOfLiving
            )
            .onChange(of: settings.monthlyCostOfLiving) { _, _ in
                settings.monthlyCostOfLivingCurrency = displayCurrency
            }

            TQCurrencyField(
                title: "Emergency Reserve (Target)",
                currency: settings.emergencyReserveTargetCurrency,
                value: $settings.emergencyReserveTarget
            )
            .onChange(of: settings.emergencyReserveTarget) { _, _ in
                settings.emergencyReserveTargetCurrency = displayCurrency
            }

            TQCurrencyField(
                title: "Emergency Reserve (Current)",
                currency: settings.emergencyReserveCurrentCurrency,
                value: $settings.emergencyReserveCurrent
            )
            .onChange(of: settings.emergencyReserveCurrent) { _, _ in
                settings.emergencyReserveCurrentCurrency = displayCurrency
            }
        }

        Section("Rebalancing") {
            Stepper(
                "Recommendations per investment: \(settings.recommendationCount)",
                value: $settings.recommendationCount,
                in: 1...10
            )
        }
    }
}
