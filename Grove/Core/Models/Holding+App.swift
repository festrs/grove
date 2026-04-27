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

    static func canAddMore(modelContext: ModelContext) -> Bool {
        let count = (try? modelContext.fetchCount(FetchDescriptor<Holding>())) ?? 0
        return count < AppConstants.freeTierMaxHoldings
    }

    static func remainingSlots(modelContext: ModelContext) -> Int {
        let count = (try? modelContext.fetchCount(FetchDescriptor<Holding>())) ?? 0
        return max(AppConstants.freeTierMaxHoldings - count, 0)
    }

    static var freeTierLimitMessage: String {
        "Limit of \(AppConstants.freeTierMaxHoldings) assets on the free plan."
    }
}
