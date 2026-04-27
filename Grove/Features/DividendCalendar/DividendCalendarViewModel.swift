import Foundation
import SwiftData
import GroveDomain

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

    /// Build a calendar entry from a stored payment. Returns nil when the payment
    /// is detached from a holding (no ticker to display).
    init?(from payment: DividendPayment) {
        guard let ticker = payment.holding?.ticker else { return nil }
        self.symbol = payment.holding?.displayTicker ?? ticker
        self.type = payment.taxTreatment.displayName
        self.amount = payment.netAmountMoney
        self.date = payment.paymentDate
    }
}

@Observable
final class DividendCalendarViewModel {
    var selectedMonth: Date = .now
    var allDividends: [CalendarDividend] = []
    var dividendsForMonth: [CalendarDividend] = []
    var selectedDay: Date?
    var dividendsForDay: [CalendarDividend] = []
    var monthlyTotal: Money = .zero(in: .brl)
    private var displayCurrency: Currency = .brl
    private var ratesProvider: any ExchangeRates = IdentityRates()

    var daysWithDividends: Set<Int> {
        Set(dividendsForMonth.map { Calendar.current.component(.day, from: $0.date) })
    }

    func loadFromLocal(modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        self.displayCurrency = displayCurrency
        self.ratesProvider = rates

        let descriptor = FetchDescriptor<DividendPayment>(
            sortBy: [SortDescriptor(\.paymentDate, order: .reverse)]
        )
        do {
            let allPayments = try modelContext.fetch(descriptor)
            allDividends = allPayments.compactMap(CalendarDividend.init(from:))
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
        monthlyTotal = dividendsForMonth.map { $0.amount }.sum(in: displayCurrency, using: ratesProvider)
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
