import Foundation
import SwiftData
import GroveDomain

/// Shared backing for the allocation editor — used by both the iOS
/// `AllocationSettingsView` and the macOS Settings → Portfolio tab. Owns the
/// per-class weights, change tracking, and the load/save round-trip against
/// `UserSettings.classAllocations`.
@Observable
@MainActor
final class AllocationSettingsViewModel {
    /// All asset classes start at 0 so steppers render numeric values from
    /// the first frame. `load(modelContext:)` overwrites with stored data.
    var weights: [AssetClassType: Double]
    var hasChanges: Bool = false

    init() {
        var initial: [AssetClassType: Double] = [:]
        for cls in AssetClassType.allCases { initial[cls] = 0 }
        self.weights = initial
    }

    var total: Double {
        weights.values.reduce(0, +)
    }

    /// Allocation must sum exactly to 100 (with a small float tolerance).
    var isValid: Bool {
        abs(total - 100) < 0.5
    }

    func setWeight(_ value: Double, for cls: AssetClassType) {
        weights[cls] = value
        hasChanges = true
    }

    func load(modelContext: ModelContext) {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        if let settings = try? modelContext.fetch(descriptor).first {
            for (cls, value) in settings.classAllocations {
                weights[cls] = value
            }
        }
        for cls in AssetClassType.allCases where weights[cls] == nil {
            weights[cls] = 0
        }
        hasChanges = false
    }

    /// Persist the current weights. Returns true when the save was applied;
    /// false when the form is invalid (sum ≠ 100) so the view can keep the
    /// Save button visible without trashing the user's draft.
    @discardableResult
    func save(modelContext: ModelContext) -> Bool {
        guard isValid else { return false }
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        guard let settings = try? modelContext.fetch(descriptor).first else { return false }
        settings.classAllocations = weights
        try? modelContext.save()
        hasChanges = false
        return true
    }
}
