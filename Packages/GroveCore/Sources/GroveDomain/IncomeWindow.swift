import Foundation

/// Time window for aggregating dividend income (paid + projected). Used by
/// the passive-income drilldown to show day/week/month/year totals side by
/// side. Date ranges are calendar-aware so "month" means the current
/// calendar month, not "trailing 30 days".
public enum IncomeWindow: Sendable, Hashable {
    case day
    case week
    case month
    case year
    case custom(start: Date, end: Date)

    /// Closed range over which `DividendPayment.paymentDate` is matched.
    /// Anchored to `asOf` so tests can pin a deterministic clock.
    public func dateRange(asOf: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        switch self {
        case .day:
            let start = calendar.startOfDay(for: asOf)
            let end = calendar.date(byAdding: .day, value: 1, to: start)
                .flatMap { calendar.date(byAdding: .second, value: -1, to: $0) } ?? asOf
            return start...end
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: asOf)
            let start = interval?.start ?? asOf
            let end = interval.map { calendar.date(byAdding: .second, value: -1, to: $0.end) ?? $0.end } ?? asOf
            return start...end
        case .month:
            let interval = calendar.dateInterval(of: .month, for: asOf)
            let start = interval?.start ?? asOf
            let end = interval.map { calendar.date(byAdding: .second, value: -1, to: $0.end) ?? $0.end } ?? asOf
            return start...end
        case .year:
            let interval = calendar.dateInterval(of: .year, for: asOf)
            let start = interval?.start ?? asOf
            let end = interval.map { calendar.date(byAdding: .second, value: -1, to: $0.end) ?? $0.end } ?? asOf
            return start...end
        case let .custom(start, end):
            return start <= end ? start...end : end...start
        }
    }
}
