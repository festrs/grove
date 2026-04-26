import Testing
import Foundation
@testable import Grove

struct DividendCalendarViewModelTests {

    private func makeDividend(symbol: String, amount: Decimal, date: Date) -> CalendarDividend {
        CalendarDividend(symbol: symbol, type: "Dividend", amount: Money(amount: amount, currency: .brl), date: date)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Filtering

    @Test func filterForMonthFiltersCorrectly() {
        let vm = DividendCalendarViewModel()
        vm.selectedMonth = date(year: 2026, month: 4, day: 1)
        vm.allDividends = [
            makeDividend(symbol: "A", amount: 10, date: date(year: 2026, month: 4, day: 5)),
            makeDividend(symbol: "B", amount: 20, date: date(year: 2026, month: 4, day: 15)),
            makeDividend(symbol: "C", amount: 30, date: date(year: 2026, month: 3, day: 10)),
            makeDividend(symbol: "D", amount: 40, date: date(year: 2026, month: 5, day: 1)),
        ]
        vm.filterForMonth()

        #expect(vm.dividendsForMonth.count == 2)
        #expect(vm.monthlyTotal.amount == 30)
    }

    @Test func filterForMonthResetsSelection() {
        let vm = DividendCalendarViewModel()
        vm.selectedDay = .now
        vm.dividendsForDay = [makeDividend(symbol: "X", amount: 5, date: .now)]

        vm.selectedMonth = date(year: 2026, month: 4, day: 1)
        vm.allDividends = []
        vm.filterForMonth()

        #expect(vm.selectedDay == nil)
        #expect(vm.dividendsForDay.isEmpty)
    }

    @Test func filterForMonthWithNoDividends() {
        let vm = DividendCalendarViewModel()
        vm.selectedMonth = date(year: 2026, month: 6, day: 1)
        vm.allDividends = [
            makeDividend(symbol: "A", amount: 10, date: date(year: 2026, month: 4, day: 5)),
        ]
        vm.filterForMonth()

        #expect(vm.dividendsForMonth.isEmpty)
        #expect(vm.monthlyTotal.amount == 0)
    }

    // MARK: - Day Selection

    @Test func selectDayFiltersDividends() {
        let vm = DividendCalendarViewModel()
        vm.selectedMonth = date(year: 2026, month: 4, day: 1)
        vm.allDividends = [
            makeDividend(symbol: "A", amount: 10, date: date(year: 2026, month: 4, day: 5)),
            makeDividend(symbol: "B", amount: 20, date: date(year: 2026, month: 4, day: 5)),
            makeDividend(symbol: "C", amount: 30, date: date(year: 2026, month: 4, day: 15)),
        ]
        vm.filterForMonth()
        vm.selectDay(5)

        #expect(vm.dividendsForDay.count == 2)
        #expect(vm.selectedDay != nil)
        #expect(Calendar.current.component(.day, from: vm.selectedDay!) == 5)
    }

    @Test func selectDayWithNoDividends() {
        let vm = DividendCalendarViewModel()
        vm.selectedMonth = date(year: 2026, month: 4, day: 1)
        vm.allDividends = []
        vm.filterForMonth()
        vm.selectDay(10)

        #expect(vm.dividendsForDay.isEmpty)
    }

    // MARK: - Month Navigation

    @Test func previousMonthGoesBack() {
        let vm = DividendCalendarViewModel()
        vm.selectedMonth = date(year: 2026, month: 4, day: 1)
        vm.allDividends = []
        vm.previousMonth()

        #expect(Calendar.current.component(.month, from: vm.selectedMonth) == 3)
    }

    @Test func nextMonthGoesForward() {
        let vm = DividendCalendarViewModel()
        vm.selectedMonth = date(year: 2026, month: 4, day: 1)
        vm.allDividends = []
        vm.nextMonth()

        #expect(Calendar.current.component(.month, from: vm.selectedMonth) == 5)
    }

    @Test func monthNavigationRefilters() {
        let vm = DividendCalendarViewModel()
        vm.selectedMonth = date(year: 2026, month: 4, day: 1)
        vm.allDividends = [
            makeDividend(symbol: "A", amount: 10, date: date(year: 2026, month: 5, day: 5)),
        ]
        vm.filterForMonth()
        #expect(vm.dividendsForMonth.isEmpty)

        vm.nextMonth()
        #expect(vm.dividendsForMonth.count == 1)
    }

    // MARK: - daysWithDividends

    @Test func daysWithDividendsComputed() {
        let vm = DividendCalendarViewModel()
        vm.selectedMonth = date(year: 2026, month: 4, day: 1)
        vm.allDividends = [
            makeDividend(symbol: "A", amount: 10, date: date(year: 2026, month: 4, day: 5)),
            makeDividend(symbol: "B", amount: 20, date: date(year: 2026, month: 4, day: 5)),
            makeDividend(symbol: "C", amount: 30, date: date(year: 2026, month: 4, day: 15)),
        ]
        vm.filterForMonth()

        #expect(vm.daysWithDividends == [5, 15])
    }
}
