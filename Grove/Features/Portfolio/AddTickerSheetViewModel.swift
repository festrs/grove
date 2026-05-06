import Foundation
import SwiftData
import GroveDomain
import GroveRepositories

/// Backs `AddTickerSheet` — the single global add-ticker entry point. Owns
/// the search field state, debouncer, and "already added" check so the view
/// stays layout-only.
///
/// Selecting a real result or tapping the "Add custom ticker" row both
/// route to `AddAssetDetailSheet`; this VM just emits the chosen target
/// back to the parent.
@Observable
@MainActor
final class AddTickerSheetViewModel {
    var searchText: String = ""
    var debouncer = SearchDebouncer()
    var errorMessage: String?

    private var existingTickers: Set<String> = []

    /// Snapshot of tickers currently in the portfolio so we can dim
    /// already-added rows and suppress the custom-add row when the typed
    /// symbol already exists.
    func loadExistingTickers(modelContext: ModelContext) {
        let repo = PortfolioRepository(modelContext: modelContext)
        let holdings = (try? repo.fetchAllHoldings()) ?? []
        existingTickers = Set(holdings.map { $0.ticker.normalizedTicker })
    }

    func isAlreadyAdded(_ symbol: String) -> Bool {
        existingTickers.contains(symbol.normalizedTicker)
    }

    /// True when the typed text could be saved as a custom ticker — non-empty,
    /// not currently mid-search, and not already in the portfolio.
    func canAddAsCustom(trimmed: String, isSearching: Bool) -> Bool {
        !trimmed.isEmpty && !isSearching && !isAlreadyAdded(trimmed)
    }
}
