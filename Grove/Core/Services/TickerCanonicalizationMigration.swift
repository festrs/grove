import Foundation
import SwiftData
import GroveDomain

/// One-shot migration that brings legacy locally-stored BR/FII tickers up to
/// the canonical `.SA` form. Runs at app launch and gates itself on a
/// UserDefaults flag so the work happens at most once per device.
///
/// The rule is asset-class driven, not pattern-based: any `Holding` whose
/// `assetClass` is `.acoesBR` or `.fiis` and whose `ticker` doesn't already
/// end in `.SA` gets the suffix appended. The backend now sends BR symbols
/// in canonical form on every endpoint, so once this migration has run the
/// local store matches what the backend writes on subsequent syncs.
enum TickerCanonicalizationMigration {

    private static let didRunKey = "grove.migration.tickerCanonicalSA.v1"

    /// Idempotent. Safe to call on every launch — the flag short-circuits
    /// repeated runs, and the inner check is a no-op when nothing matches.
    @MainActor
    static func runIfNeeded(modelContext: ModelContext) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: didRunKey) { return }

        do {
            let descriptor = FetchDescriptor<Holding>()
            let holdings = try modelContext.fetch(descriptor)
            var updated = 0
            for h in holdings where needsSASuffix(h) {
                h.ticker += ".SA"
                updated += 1
            }
            if updated > 0 {
                try modelContext.save()
                print("[Migration] tickerCanonicalSA: appended .SA to \(updated) holding(s)")
            }
            defaults.set(true, forKey: didRunKey)
        } catch {
            print("[Migration] tickerCanonicalSA: failed — \(error.localizedDescription)")
        }
    }

    private static func needsSASuffix(_ h: Holding) -> Bool {
        guard h.assetClass == .acoesBR || h.assetClass == .fiis else { return false }
        guard !h.isCustom else { return false }
        let t = h.ticker
        return !t.isEmpty && !t.hasSuffix(".SA")
    }
}
