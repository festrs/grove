import Foundation
import UserNotifications

struct NotificationCoordinator {
    private static let defaults = UserDefaults.standard

    // MARK: - Toggle keys (match @AppStorage keys in NotificationSettingsSection)

    private static var monthlyEnabled: Bool { defaults.bool(forKey: "notif_monthly") }
    private static var dividendsEnabled: Bool { defaults.bool(forKey: "notif_dividends") }
    private static var milestonesEnabled: Bool { defaults.bool(forKey: "notif_milestones") }
    private static var driftEnabled: Bool { defaults.bool(forKey: "notif_drift") }

    // MARK: - App Launch

    static func handleAppLaunch() async {
        let granted = await NotificationService.shared.requestPermission()
        guard granted else { return }

        if monthlyEnabled {
            await NotificationService.shared.scheduleMonthlyRebalancingReminder()
        } else {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["monthly-rebalancing"])
        }
    }

    // MARK: - Dividend Notifications

    static func handleNewDividends(_ payments: [(ticker: String, amount: Money, date: Date)]) async {
        guard dividendsEnabled else { return }
        for p in payments {
            await NotificationService.shared.scheduleDividendNotification(
                ticker: p.ticker, amount: p.amount, date: p.date
            )
        }
    }

    // MARK: - Milestone Check

    static func handleMilestoneCheck(progressPercent: Decimal) async {
        guard milestonesEnabled else { return }

        let milestones = [25, 50, 75, 100]
        let currentInt = Int(NSDecimalNumber(decimal: progressPercent).doubleValue)
        let lastNotified = defaults.integer(forKey: "notif_lastMilestone")

        for m in milestones where m > lastNotified && currentInt >= m {
            await NotificationService.shared.scheduleMilestoneNotification(percent: m)
            defaults.set(m, forKey: "notif_lastMilestone")
        }
    }

    // MARK: - Drift Check

    static func handleDriftCheck(allocations: [AssetClassAllocation]) async {
        guard driftEnabled else { return }

        // Throttle: max once per 7 days
        let lastDrift = defaults.object(forKey: "notif_lastDriftDate") as? Date ?? .distantPast
        guard lastDrift.timeIntervalSinceNow < -(7 * 24 * 60 * 60) else { return }

        let drifted = allocations.filter {
            abs(NSDecimalNumber(decimal: $0.drift).doubleValue) > 5.0
        }
        guard let worst = drifted.max(by: {
            abs(NSDecimalNumber(decimal: $0.drift).doubleValue) < abs(NSDecimalNumber(decimal: $1.drift).doubleValue)
        }) else { return }

        await NotificationService.shared.scheduleDriftNotification(
            assetClass: worst.assetClass.displayName,
            driftPercent: worst.drift
        )
        defaults.set(Date.now, forKey: "notif_lastDriftDate")
    }
}
