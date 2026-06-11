import Foundation
import SwiftData
import GroveDomain

struct DividendRepository {
    let modelContext: ModelContext

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
