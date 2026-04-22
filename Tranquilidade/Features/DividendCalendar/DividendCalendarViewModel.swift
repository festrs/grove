import Foundation
import SwiftData

struct CalendarDividend: Identifiable {
    var id: String { "\(symbol)-\(date.timeIntervalSince1970)-\(type)" }
    let symbol: String
    let type: String
    let amount: Decimal
    let currency: String
    let date: Date
}

@Observable
final class DividendCalendarViewModel {
    var selectedMonth: Date = .now
    var allDividends: [CalendarDividend] = []
    var dividendsForMonth: [CalendarDividend] = []
    var selectedDay: Date?
    var dividendsForDay: [CalendarDividend] = []
    var monthlyTotal: Decimal = 0

    var daysWithDividends: Set<Int> {
        Set(dividendsForMonth.map { Calendar.current.component(.day, from: $0.date) })
    }

    /// Load from local SwiftData
    func loadFromLocal(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<DividendPayment>(
            sortBy: [SortDescriptor(\.paymentDate, order: .reverse)]
        )
        do {
            let allPayments = try modelContext.fetch(descriptor)
            allDividends = allPayments.compactMap { payment in
                guard let ticker = payment.holding?.ticker else { return nil }
                return CalendarDividend(
                    symbol: payment.holding?.displayTicker ?? ticker,
                    type: payment.taxTreatment.displayName,
                    amount: payment.netAmount,
                    currency: "BRL",
                    date: payment.paymentDate
                )
            }
            filterForMonth()
        } catch {
            allDividends = []
        }
    }

    func filterForMonth() {
        let cal = Calendar.current
        dividendsForMonth = allDividends.filter { div in
            cal.component(.year, from: div.date) == cal.component(.year, from: selectedMonth) &&
            cal.component(.month, from: div.date) == cal.component(.month, from: selectedMonth)
        }
        monthlyTotal = dividendsForMonth.reduce(Decimal.zero) { $0 + $1.amount }
        selectedDay = nil
        dividendsForDay = []
    }

    func selectDay(_ day: Int) {
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month], from: selectedMonth)
        components.day = day
        selectedDay = cal.date(from: components)
        dividendsForDay = dividendsForMonth.filter { cal.component(.day, from: $0.date) == day }
    }

    func previousMonth() {
        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        filterForMonth()
    }

    func nextMonth() {
        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        filterForMonth()
    }
}
