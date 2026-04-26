import Foundation
import UserNotifications

/// Allows notifications to display as banners even when the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

actor NotificationService {
    static let shared = NotificationService()

    func requestPermission() async -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        do {
            return try await UNUserNotificationCenter.current()
                #if os(iOS)
                .requestAuthorization(options: [.alert, .badge, .sound])
                #else
                .requestAuthorization(options: [.alert, .sound])
                #endif
        } catch {
            return false
        }
    }

    func scheduleMonthlyRebalancingReminder() async {
        let content = UNMutableNotificationContent()
        content.title = "Time to invest"
        content.body = "Open Grove to see where to invest this month."
        content.sound = .default

        // 1st business day of each month at 9am
        var dateComponents = DateComponents()
        dateComponents.day = 1
        dateComponents.hour = 9

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "monthly-rebalancing",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleDividendNotification(ticker: String, amount: Decimal, date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "\(ticker) paid a dividend"
        content.body = "\(amount.formattedBRL()) received"
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(
            identifier: "dividend-\(ticker)-\(date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleMilestoneNotification(percent: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Milestone reached!"
        content.body = "Your passive income reached \(percent)% of goal."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "milestone-\(percent)",
            content: content,
            trigger: nil // immediate
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleDriftNotification(assetClass: String, driftPercent: Decimal) async {
        let content = UNMutableNotificationContent()
        let direction = driftPercent > 0 ? "overweight" : "underweight"
        content.title = "Allocation drift detected"
        content.body = "\(assetClass) is \(direction) by \(abs(NSDecimalNumber(decimal: driftPercent).doubleValue).formatted(.number.precision(.fractionLength(1))))%."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "drift-alert",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func removeAllPending() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
