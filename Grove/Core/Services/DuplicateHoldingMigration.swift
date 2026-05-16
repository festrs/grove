import Foundation
import SwiftData
import GroveDomain

/// One-shot migration that collapses duplicate-ticker holdings within a
/// Portfolio. Grew necessary once we shipped imports — both add-via-search and
/// portfolio-import insert blindly, so a user who studied AAPL and later
/// imported a portfolio containing AAPL ended up with two rows.
///
/// Rule: per Portfolio, group by canonical `ticker` (already normalized at
/// `Holding.init`). Where a group has >1, keep the row with the richest
/// history (most transactions, tiebreak: most dividends, then identifier
/// ordering). Reassign the duplicates' Contributions and DividendPayments to
/// the primary, recalculate from transactions, then delete the duplicates.
/// Promote `.estudo` → `.aportar` on the primary if quantity ends up > 0.
///
/// Runs after `TickerCanonicalizationMigration` so rows that only became
/// duplicates *because* of `.SA` normalization are caught.
enum DuplicateHoldingMigration {

    private static let didRunKey = "grove.migration.duplicateHolding.v1"

    @MainActor
    static func runIfNeeded(modelContext: ModelContext) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: didRunKey) { return }

        do {
            let portfolios = try modelContext.fetch(FetchDescriptor<Portfolio>())
            var collapsed = 0
            for portfolio in portfolios {
                collapsed += merge(in: portfolio)
            }
            if collapsed > 0 {
                try modelContext.save()
                print("[Migration] duplicateHolding: merged \(collapsed) duplicate holding(s)")
            }
            defaults.set(true, forKey: didRunKey)
        } catch {
            print("[Migration] duplicateHolding: failed — \(error.localizedDescription)")
        }
    }

    /// Merge duplicates inside a single portfolio. Returns the number of
    /// duplicate rows deleted.
    @discardableResult
    private static func merge(in portfolio: Portfolio) -> Int {
        let groups = Dictionary(grouping: portfolio.holdings, by: \.ticker)
        var deleted = 0

        for (_, group) in groups where group.count > 1 {
            let primary = pickPrimary(from: group)
            let duplicates = group.filter { $0 !== primary }

            for dup in duplicates {
                for transaction in dup.transactions {
                    transaction.holding = primary
                }
                for dividend in dup.dividends {
                    dividend.holding = primary
                }
                primary.modelContext?.delete(dup)
                deleted += 1
            }

            primary.recalculateFromTransactions()
            if primary.quantity > 0 && primary.status == .estudo {
                primary.status = .aportar
            }
        }

        return deleted
    }

    /// Prefer the row that already has real history. Contributions outrank
    /// dividends (they drive quantity); identifier hash is the deterministic
    /// tiebreaker so repeated runs pick the same primary.
    private static func pickPrimary(from group: [Holding]) -> Holding {
        group.max { lhs, rhs in
            if lhs.transactions.count != rhs.transactions.count {
                return lhs.transactions.count < rhs.transactions.count
            }
            if lhs.dividends.count != rhs.dividends.count {
                return lhs.dividends.count < rhs.dividends.count
            }
            return lhs.persistentModelID.hashValue < rhs.persistentModelID.hashValue
        } ?? group[0]
    }
}
