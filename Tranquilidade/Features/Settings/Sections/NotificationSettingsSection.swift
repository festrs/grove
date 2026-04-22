import SwiftUI

struct NotificationSettingsSection: View {
    @AppStorage("notif_dividends") private var dividendAlerts = true
    @AppStorage("notif_monthly") private var monthlyReminder = true
    @AppStorage("notif_milestones") private var milestoneAlerts = true
    @AppStorage("notif_drift") private var driftAlerts = false

    var body: some View {
        Section("Notificacoes") {
            Toggle("Dividendos recebidos", isOn: $dividendAlerts)
            Toggle("Lembrete mensal de aporte", isOn: $monthlyReminder)
            Toggle("Marcos da meta (25%, 50%...)", isOn: $milestoneAlerts)
            Toggle("Alerta de desvio de alocacao", isOn: $driftAlerts)
        }
    }
}
