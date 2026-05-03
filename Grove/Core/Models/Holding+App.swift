import Foundation
import SwiftUI
import SwiftData
import GroveDomain

// App-only extensions on Holding that depend on theme colors and AppConstants —
// kept out of GroveDomain so the package stays free of UI-theme and app-config deps.
extension Holding {
    var gainLossColor: Color {
        gainLossPercent >= 0 ? .tqPositive : .tqNegative
    }

    static var isFreeTierBypassed: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: AppConstants.Debug.unlimitedHoldingsKey)
        #else
        return false
        #endif
    }

    static func canAddMore(currentCount: Int) -> Bool {
        if isFreeTierBypassed { return true }
        return currentCount < AppConstants.freeTierMaxHoldings
    }

    static func remainingSlots(currentCount: Int) -> Int {
        if isFreeTierBypassed { return .max }
        return max(AppConstants.freeTierMaxHoldings - currentCount, 0)
    }

    static func canAddMore(modelContext: ModelContext) -> Bool {
        let count = (try? modelContext.fetchCount(FetchDescriptor<Holding>())) ?? 0
        return canAddMore(currentCount: count)
    }

    static func remainingSlots(modelContext: ModelContext) -> Int {
        let count = (try? modelContext.fetchCount(FetchDescriptor<Holding>())) ?? 0
        return remainingSlots(currentCount: count)
    }

    static var freeTierLimitMessage: String {
        "Limit of \(AppConstants.freeTierMaxHoldings) assets on the free plan."
    }
}
