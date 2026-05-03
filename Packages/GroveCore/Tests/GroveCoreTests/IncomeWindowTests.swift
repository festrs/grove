import Testing
import Foundation
@testable import GroveDomain

struct IncomeWindowTests {

    /// Stable wall-clock anchor: 2026-04-29 (Wed) at 14:30 UTC.
    private static let anchor: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 29
        c.hour = 14; c.minute = 30; c.second = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    private static let utcCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    @Test func dayWindowSpansSingleCalendarDay() {
        let r = IncomeWindow.day.dateRange(asOf: Self.anchor, calendar: Self.utcCal)
        #expect(Self.utcCal.component(.year, from: r.lowerBound) == 2026)
        #expect(Self.utcCal.component(.month, from: r.lowerBound) == 4)
        #expect(Self.utcCal.component(.day, from: r.lowerBound) == 29)
        #expect(Self.utcCal.component(.hour, from: r.lowerBound) == 0)
        // upperBound is end-of-day
        #expect(Self.utcCal.component(.day, from: r.upperBound) == 29)
        #expect(Self.utcCal.component(.hour, from: r.upperBound) == 23)
    }

    @Test func monthWindowSpansCalendarMonth() {
        let r = IncomeWindow.month.dateRange(asOf: Self.anchor, calendar: Self.utcCal)
        #expect(Self.utcCal.component(.day, from: r.lowerBound) == 1)
        #expect(Self.utcCal.component(.month, from: r.lowerBound) == 4)
        #expect(Self.utcCal.component(.month, from: r.upperBound) == 4)
        // April 2026 has 30 days
        #expect(Self.utcCal.component(.day, from: r.upperBound) == 30)
    }

    @Test func yearWindowSpansCalendarYear() {
        let r = IncomeWindow.year.dateRange(asOf: Self.anchor, calendar: Self.utcCal)
        #expect(Self.utcCal.component(.year, from: r.lowerBound) == 2026)
        #expect(Self.utcCal.component(.month, from: r.lowerBound) == 1)
        #expect(Self.utcCal.component(.day, from: r.lowerBound) == 1)
        #expect(Self.utcCal.component(.month, from: r.upperBound) == 12)
        #expect(Self.utcCal.component(.day, from: r.upperBound) == 31)
    }

    @Test func weekWindowContainsAnchorDay() {
        let r = IncomeWindow.week.dateRange(asOf: Self.anchor, calendar: Self.utcCal)
        #expect(r.contains(Self.anchor))
        // Span should be ~7 days
        let span = r.upperBound.timeIntervalSince(r.lowerBound)
        #expect(span > 6 * 86_400 && span < 7 * 86_400)
    }

    @Test func customWindowReturnsExactRange() {
        let start = Date(timeIntervalSince1970: 1_000_000_000)
        let end = Date(timeIntervalSince1970: 1_001_000_000)
        let r = IncomeWindow.custom(start: start, end: end).dateRange(asOf: Self.anchor)
        #expect(r.lowerBound == start)
        #expect(r.upperBound == end)
    }

    @Test func customWindowSwapsReversedBounds() {
        let later = Date(timeIntervalSince1970: 1_001_000_000)
        let earlier = Date(timeIntervalSince1970: 1_000_000_000)
        let r = IncomeWindow.custom(start: later, end: earlier).dateRange(asOf: Self.anchor)
        #expect(r.lowerBound == earlier)
        #expect(r.upperBound == later)
    }
}
