import Foundation

extension Date {
    var startOfMonth: Date {
        Calendar.current.dateInterval(of: .month, for: self)?.start ?? self
    }

    var endOfMonth: Date {
        guard let interval = Calendar.current.dateInterval(of: .month, for: self) else { return self }
        return Calendar.current.date(byAdding: .second, value: -1, to: interval.end) ?? self
    }

    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self).capitalized
    }

    var shortMonthString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "MMM"
        return formatter.string(from: self).capitalized
    }

    var dayOfMonth: Int {
        Calendar.current.component(.day, from: self)
    }

    var month: Int {
        Calendar.current.component(.month, from: self)
    }

    var year: Int {
        Calendar.current.component(.year, from: self)
    }

    func monthsAgo(_ months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: -months, to: self) ?? self
    }
}
