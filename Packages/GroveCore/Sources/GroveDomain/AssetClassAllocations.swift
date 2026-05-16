import Foundation

/// Pure helpers for asset-class allocation dictionaries. Mirrors what the
/// allocation editor needs (a complete keyset for stepper rendering, a
/// total, a validity check) without taking a dependency on SwiftData or
/// SwiftUI — so the logic stays unit-testable as a value type.
public extension Dictionary where Key == AssetClassType, Value == Double {

    /// A dictionary with every `AssetClassType` mapped to 0. The editor
    /// expects every key present so steppers render numeric values from
    /// the first frame.
    static var defaultAssetClassZeros: [AssetClassType: Double] {
        var result: [AssetClassType: Double] = [:]
        for cls in AssetClassType.allCases { result[cls] = 0 }
        return result
    }

    /// Fill in any missing `AssetClassType` keys with 0 so the editor has
    /// a complete keyset to render. Existing keys are preserved.
    var withMissingAssetClassZeros: [AssetClassType: Double] {
        var copy = self
        for cls in AssetClassType.allCases where copy[cls] == nil {
            copy[cls] = 0
        }
        return copy
    }

    /// Sum of all weights.
    var allocationTotal: Double {
        values.reduce(0, +)
    }

    /// Allocation must sum to exactly 100 (with a small float tolerance).
    var isValidAllocation: Bool {
        abs(allocationTotal - 100) < 0.5
    }
}
