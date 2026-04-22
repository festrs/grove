import SwiftUI

struct GoalSettingsSection: View {
    @Bindable var settings: UserSettings

    var body: some View {
        Section("Metas") {
            TQCurrencyField(
                title: "Renda passiva mensal",
                value: $settings.monthlyIncomeGoal
            )

            TQCurrencyField(
                title: "Custo de vida mensal",
                value: $settings.monthlyCostOfLiving
            )

            TQCurrencyField(
                title: "Reserva de emergencia (alvo)",
                value: $settings.emergencyReserveTarget
            )

            TQCurrencyField(
                title: "Reserva de emergencia (atual)",
                value: $settings.emergencyReserveCurrent
            )
        }

        Section("Rebalanceamento") {
            Stepper(
                "Recomendacoes por aporte: \(settings.recommendationCount)",
                value: $settings.recommendationCount,
                in: 1...10
            )
        }
    }
}
