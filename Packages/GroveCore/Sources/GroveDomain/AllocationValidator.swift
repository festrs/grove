import Foundation

public enum AllocationValidator {
    /// True when the given allocations sum to roughly 100 (within ±1 to tolerate
    /// rounding error from sliders/percent inputs). Empty inputs are invalid.
    public static func isValid(_ allocations: [AssetClassType: Decimal]) -> Bool {
        guard !allocations.isEmpty else { return false }
        let total = allocations.values.reduce(Decimal.zero, +)
        return total >= 99 && total <= 101
    }
}
