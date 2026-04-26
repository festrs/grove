import SwiftUI

struct GoalSettingsSection: View {
    @Bindable var settings: UserSettings

    var body: some View {
        Section("Goals") {
            TQCurrencyField(
                title: "Monthly Passive Income",
                value: $settings.monthlyIncomeGoal
            )

            TQCurrencyField(
                title: "Monthly Cost of Living",
                value: $settings.monthlyCostOfLiving
            )

            TQCurrencyField(
                title: "Emergency Reserve (Target)",
                value: $settings.emergencyReserveTarget
            )

            TQCurrencyField(
                title: "Emergency Reserve (Current)",
                value: $settings.emergencyReserveCurrent
            )
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
