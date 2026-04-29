import Foundation
import SwiftData
import GroveDomain

/// Owns the refresh-from-backend flow for `AssetClassDividendsView`. Keeps
/// the view as pure layout: state transitions (`isRefreshing`, error
/// surfacing) and the two-step refresh (on-demand scrape + local sync) live
/// here so they're testable without SwiftUI in the loop.
@Observable
@MainActor
final class AssetClassDividendsViewModel {
    var isRefreshing = false
    var errorMessage: String?

    /// Trigger an on-demand dividend scrape on the backend for the given
    /// tickers, then re-sync the local store so the new records appear.
    /// Re-entrant calls and empty-symbol calls are no-ops.
    func refresh(
        symbols: [String],
        assetClass: AssetClassType,
        modelContext: ModelContext,
        backendService: any BackendServiceProtocol,
        syncService: SyncService
    ) async {
        guard !isRefreshing else { return }
        guard !symbols.isEmpty else { return }

        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            // Manual refresh — leave `since` nil so the user can backfill
            // the full history (e.g. after importing a legacy position).
            _ = try await backendService.refreshDividends(
                symbols: symbols,
                assetClass: assetClass.rawValue,
                since: nil
            )
            try await syncService.syncDividends(
                modelContext: modelContext,
                backendService: backendService
            )
            try? modelContext.save()
        } catch {
            errorMessage = "Couldn't refresh dividends: \(error.localizedDescription)"
        }
    }
}
