import Testing
import Foundation
import GroveDomain
@testable import Grove

/// Pure-function tests for the calendar's filtering helpers (extracted from
/// the now-deleted DividendCalendarViewModel). Month navigation and
/// selected-day state are SwiftUI bindings on the view and verified visually.
struct CalendarDividendFilterTests {

    private func makeDividend(symbol: String, amount: Decimal, date: Date) -> CalendarDividend {
        CalendarDividend(symbol: symbol, type: "Dividend", amount: Money(amount: amount, currency: .brl), date: date)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func inMonthKeepsOnlyMatchingYearMonth() {
        let all = [
            makeDividend(symbol: "A", amount: 10, date: date(year: 2026, month: 4, day: 5)),
            makeDividend(symbol: "B", amount: 20, date: date(year: 2026, month: 4, day: 15)),
            makeDividend(symbol: "C", amount: 30, date: date(year: 2026, month: 3, day: 10)),
            makeDividend(symbol: "D", amount: 40, date: date(year: 2026, month: 5, day: 1)),
        ]

        let april = all.inMonth(date(year: 2026, month: 4, day: 1))
        #expect(april.count == 2)
        #expect(april.map(\.symbol).sorted() == ["A", "B"])
    }

    @Test func inMonthReturnsEmptyWhenNoneMatch() {
        let all = [
            makeDividend(symbol: "A", amount: 10, date: date(year: 2026, month: 4, day: 5)),
        ]
        let june = all.inMonth(date(year: 2026, month: 6, day: 1))
        #expect(june.isEmpty)
    }

    @Test func onDayFiltersWithinMonth() {
        let april = [
            makeDividend(symbol: "A", amount: 10, date: date(year: 2026, month: 4, day: 5)),
            makeDividend(symbol: "B", amount: 20, date: date(year: 2026, month: 4, day: 5)),
            makeDividend(symbol: "C", amount: 30, date: date(year: 2026, month: 4, day: 15)),
        ]
        let day5 = april.onDay(5)
        #expect(day5.count == 2)
        #expect(day5.map(\.symbol).sorted() == ["A", "B"])
    }

    @Test func onDayReturnsEmptyWhenNoMatch() {
        let april = [
            makeDividend(symbol: "A", amount: 10, date: date(year: 2026, month: 4, day: 5)),
        ]
        #expect(april.onDay(10).isEmpty)
    }

    @Test func daysWithDividendsReturnsUniqueDayNumbers() {
        let april = [
            makeDividend(symbol: "A", amount: 10, date: date(year: 2026, month: 4, day: 5)),
            makeDividend(symbol: "B", amount: 20, date: date(year: 2026, month: 4, day: 5)),
            makeDividend(symbol: "C", amount: 30, date: date(year: 2026, month: 4, day: 15)),
        ]
        #expect(april.daysWithDividends() == [5, 15])
    }
}
