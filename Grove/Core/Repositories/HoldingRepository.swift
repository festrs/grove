import Foundation
import SwiftData

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

    func fetchByAssetClass(_ assetClass: AssetClassType) throws -> [Holding] {
        let classRaw = assetClass.rawValue
        let descriptor = FetchDescriptor<Holding>(
            predicate: #Predicate { $0.assetClassRaw == classRaw },
            sortBy: [SortDescriptor(\.ticker)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchEligibleForRebalancing() throws -> [Holding] {
        try fetchByStatus(.aportar)
    }

    func holdingCount() throws -> Int {
        let descriptor = FetchDescriptor<Holding>()
        return try modelContext.fetchCount(descriptor)
    }
}
