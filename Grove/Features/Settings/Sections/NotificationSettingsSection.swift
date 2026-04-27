import SwiftUI
import UserNotifications

struct NotificationSettingsSection: View {
    @AppStorage("notif_dividends") private var dividendAlerts = true
    @AppStorage("notif_monthly") private var monthlyReminder = true
    @AppStorage("notif_milestones") private var milestoneAlerts = true
    @AppStorage("notif_drift") private var driftAlerts = false

    var body: some View {
        Section("Notifications") {
            Toggle("Received Dividends", isOn: $dividendAlerts)
            Toggle("Monthly Investment Reminder", isOn: $monthlyReminder)
                .onChange(of: monthlyReminder) { _, enabled in
                    Task {
                        if enabled {
                            await NotificationService.shared.scheduleMonthlyRebalancingReminder()
                        } else {
                            UNUserNotificationCenter.current()
                                .removePendingNotificationRequests(withIdentifiers: ["monthly-rebalancing"])
                        }
                    }
                }
            Toggle("Goal Milestones (25%, 50%...)", isOn: $milestoneAlerts)
            Toggle("Allocation Drift Alert", isOn: $driftAlerts)
        }
    }
}
