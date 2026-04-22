import Foundation
import UserNotifications

actor NotificationService {
    static let shared = NotificationService()

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleMonthlyRebalancingReminder() async {
        let content = UNMutableNotificationContent()
        content.title = "Hora de aportar"
        content.body = "Abra o Tranquilidade para ver onde investir este mes."
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
        content.title = "\(ticker) pagou dividendo"
        content.body = "\(amount.formattedBRL()) recebido"
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
        content.title = "Marco atingido!"
        content.body = "Sua renda passiva atingiu \(percent)% da meta."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "milestone-\(percent)",
            content: content,
            trigger: nil // immediate
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func removeAllPending() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
