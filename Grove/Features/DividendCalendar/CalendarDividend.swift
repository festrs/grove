import Foundation
import GroveDomain

/// Calendar-row projection of a `DividendPayment`. Decouples the calendar
/// view from the persistence model so the filter helpers can be tested
/// without spinning up SwiftData.
struct CalendarDividend: Identifiable {
    var id: String { "\(symbol)-\(date.timeIntervalSince1970)-\(type)" }
    let symbol: String
    let type: String
    let amount: Money
    let date: Date

    init(symbol: String, type: String, amount: Money, date: Date) {
        self.symbol = symbol
        self.type = type
        self.amount = amount
        self.date = date
    }

    /// Build a calendar entry from a stored payment. Returns nil when the
    /// payment is detached from a holding (no ticker to display).
    init?(from payment: DividendPayment) {
        guard let ticker = payment.holding?.ticker else { return nil }
        self.symbol = payment.holding?.displayTicker ?? ticker
        self.type = payment.taxTreatment.displayName
        self.amount = payment.netAmountMoney
        self.date = payment.paymentDate
    }
}

extension Array where Element == CalendarDividend {
    /// Filter to rows whose `date` falls in the same year+month as `month`.
    func inMonth(_ month: Date, calendar: Calendar = .current) -> [CalendarDividend] {
        let targetYear = calendar.component(.year, from: month)
        let targetMonth = calendar.component(.month, from: month)
        return filter {
            calendar.component(.year, from: $0.date) == targetYear &&
            calendar.component(.month, from: $0.date) == targetMonth
        }
    }

    /// Filter to rows whose day-of-month equals `day` (assumes the receiver
    /// is already scoped to a single month).
    func onDay(_ day: Int, calendar: Calendar = .current) -> [CalendarDividend] {
        filter { calendar.component(.day, from: $0.date) == day }
    }

    /// Set of day-of-month values present in the receiver.
    func daysWithDividends(calendar: Calendar = .current) -> Set<Int> {
        Set(map { calendar.component(.day, from: $0.date) })
    }
}
