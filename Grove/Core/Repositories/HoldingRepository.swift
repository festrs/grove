import Foundation
import SwiftData
import GroveDomain

struct HoldingRepository {
    let modelContext: ModelContext

    func fetchAll() throws -> [Holding] {
        let descriptor = FetchDescriptor<Holding>(
            sortBy: [SortDescriptor(\.ticker)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByStatus(_ status: HoldingStatus) throws -> [Holding] {
        let statusRaw = status.rawValue
        let descriptor = FetchDescriptor<Holding>(
            predicate: #Predicate { $0.statusRaw == statusRaw },
            sortBy: [SortDescriptor(\.ticker)]
        )
        return try modelContext.fetch(descriptor)
    }
}
