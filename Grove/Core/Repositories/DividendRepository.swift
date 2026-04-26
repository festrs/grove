import Foundation
import SwiftData

struct MonthlyDividendSummary: Identifiable {
    var id: String { "\(year)-\(month)" }
    let year: Int
    let month: Int
    let gross: Decimal
    let tax: Decimal
    let net: Decimal
    let payments: [DividendPayment]

    var grossMoney: Money { Money(amount: gross, currency: .brl) }
    var netMoney: Money { Money(amount: net, currency: .brl) }

    var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "MMM"
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else { return "" }
        return formatter.string(from: date).capitalized
    }
}

struct DividendRepository {
    let modelContext: ModelContext

    func fetchAllDividends() throws -> [DividendPayment] {
        let descriptor = FetchDescriptor<DividendPayment>(
            sortBy: [SortDescriptor(\.paymentDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchDividends(for month: Date) throws -> [DividendPayment] {
        let start = month.startOfMonth
        let end = month.endOfMonth
        let descriptor = FetchDescriptor<DividendPayment>(
            predicate: #Predicate { $0.paymentDate >= start && $0.paymentDate <= end },
            sortBy: [SortDescriptor(\.paymentDate)]
        )
        return try modelContext.fetch(descriptor)
    }

    func monthlyHistory(months: Int = 12) throws -> [MonthlyDividendSummary] {
        let allDividends = try fetchAllDividends()

        let calendar = Calendar.current
        let now = Date.now

        var summaries: [MonthlyDividendSummary] = []

        for i in 0..<months {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let year = calendar.component(.year, from: monthDate)
            let month = calendar.component(.month, from: monthDate)

            let monthPayments = allDividends.filter { payment in
                let pYear = calendar.component(.year, from: payment.paymentDate)
                let pMonth = calendar.component(.month, from: payment.paymentDate)
                return pYear == year && pMonth == month
            }

            let gross = monthPayments.reduce(Decimal.zero) { $0 + $1.totalAmount }
            let tax = monthPayments.reduce(Decimal.zero) { $0 + $1.withholdingTax }

            summaries.append(MonthlyDividendSummary(
                year: year,
                month: month,
                gross: gross,
                tax: tax,
                net: gross - tax,
                payments: monthPayments
            ))
        }

        return summaries.reversed()
    }

    func upcomingDividends(days: Int = 30) throws -> [DividendPayment] {
        let now = Date.now
        guard let futureDate = Calendar.current.date(byAdding: .day, value: days, to: now) else {
            return []
        }
        let descriptor = FetchDescriptor<DividendPayment>(
            predicate: #Predicate { $0.paymentDate >= now && $0.paymentDate <= futureDate },
            sortBy: [SortDescriptor(\.paymentDate)]
        )
        return try modelContext.fetch(descriptor)
    }
}
