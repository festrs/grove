import Foundation
import SwiftData
import GroveDomain

/// Backs `AssetClassDividendsView`. Owns the manual refresh flow only —
/// per-holding dividend classification (earned vs informational) and totals
/// live on `Holding` itself in GroveDomain.
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

        let start = Date()
        print("[Dividends] AssetClassRefresh start — class=\(assetClass.rawValue) symbols=\(symbols.joined(separator: ","))")
        do {
            // Manual refresh — leave `since` nil so the user can backfill
            // the full history (e.g. after importing a legacy position).
            let result = try await backendService.refreshDividends(
                symbols: symbols,
                assetClass: assetClass.rawValue,
                since: nil
            )
            print("[Dividends] AssetClassRefresh /refresh result — scraped=\(result.scraped) new=\(result.newRecords) failed=\(result.failed)")
            try await syncService.syncDividends(
                modelContext: modelContext,
                backendService: backendService
            )
            try? modelContext.save()
            print("[Dividends] AssetClassRefresh done in \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
        } catch {
            errorMessage = "Couldn't refresh dividends: \(error.localizedDescription)"
            print("[Dividends] AssetClassRefresh FAILED after \(String(format: "%.2f", Date().timeIntervalSince(start)))s — \(error.localizedDescription)")
        }
    }
}
