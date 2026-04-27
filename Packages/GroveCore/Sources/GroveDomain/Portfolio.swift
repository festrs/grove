import Foundation
import SwiftData

@Model
public final class Portfolio {
    public var name: String
    public var createdAt: Date

    /// Asset class allocation targets as JSON: {"acoesBR": 40, "fiis": 30, ...}
    /// Must sum to 100. This is the source of truth for rebalancing.
    public var classAllocationJSON: String = "{}"

    @Relationship(deleteRule: .cascade, inverse: \Holding.portfolio)
    public var holdings: [Holding]

    public init(name: String = "Meu Portfolio", createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
        self.classAllocationJSON = "{}"
        self.holdings = []
    }

    // MARK: - Class Allocation Accessors

    public var classAllocations: [AssetClassType: Double] {
        get {
            guard let data = classAllocationJSON.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            var result: [AssetClassType: Double] = [:]
            for (key, value) in dict {
                if let ct = AssetClassType(rawValue: key) {
                    result[ct] = value
                }
            }
            return result
        }
        set {
            let dict = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, $0.value) })
            if let data = try? JSONEncoder().encode(dict),
               let json = String(data: data, encoding: .utf8) {
                classAllocationJSON = json
            }
        }
    }

    public func allocationPercent(for assetClass: AssetClassType) -> Double {
        classAllocations[assetClass] ?? 0
    }
}
