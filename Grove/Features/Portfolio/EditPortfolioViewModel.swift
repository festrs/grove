import Foundation
import SwiftData
import GroveDomain

/// Backs `EditPortfolioView`. The name field uses `@Bindable` directly
/// against the `Portfolio` SwiftData model (writes are autosaved), so the
/// VM only needs to host the destructive delete action.
@Observable
@MainActor
final class EditPortfolioViewModel {
    func delete(portfolio: Portfolio, modelContext: ModelContext) {
        modelContext.delete(portfolio)
        try? modelContext.save()
    }
}
