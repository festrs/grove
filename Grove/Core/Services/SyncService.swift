import Foundation
import SwiftData
import GroveDomain

@Observable
final class SyncService {
    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: String?

    private static let lastDividendSyncKey = "grove.lastDividendSyncDate"

    /// Sync market data: pull fresh prices for local holdings.
    /// Tracked-symbols registration is NOT done here — it's wired into each
    /// add path (AddHolding, AddAsset, NewTransaction, Import) and the final
    /// onboarding commit, so the backend already knows the set by the time
    /// `syncAll` runs. Dividend history is also out of band — see
    /// `syncDividendsIfStale` and `TickerBootstrapService`.
    func syncAll(modelContext: ModelContext, backendService: any BackendServiceProtocol) async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        let start = Date()
        print("[Sync] syncAll start")
        do {
            try await syncPrices(modelContext: modelContext, backendService: backendService)
            try modelContext.save()
            lastSyncDate = .now
            print("[Sync] syncAll done in \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
        } catch {
            syncError = error.localizedDescription
            print("[Sync] syncAll failed after \(String(format: "%.2f", Date().timeIntervalSince(start)))s: \(error.localizedDescription)")
        }
    }

    /// Fetch latest prices for all local holdings.
    ///
    /// Holdings are grouped by `normalizedTicker` (uppercased, `.SA` stripped)
    /// so suffix variants of the same asset (e.g. `ITUB3` vs `ITUB3.SA`) send
    /// a single API symbol and every matching local row picks up the price.
    func syncPrices(modelContext: ModelContext, backendService: any BackendServiceProtocol) async throws {
        let descriptor = FetchDescriptor<Holding>()
        let holdings = try modelContext.fetch(descriptor).filter { !$0.isCustom }
        guard !holdings.isEmpty else { return }

        var holdingsByNormalized: [String: [Holding]] = [:]
        for h in holdings {
            holdingsByNormalized[h.ticker.normalizedTicker, default: []].append(h)
        }
        let symbols = Array(holdingsByNormalized.keys).sorted()
        let dupCount = holdings.count - symbols.count
        if dupCount > 0 {
            print("[Sync] syncPrices: \(holdings.count) holdings → \(symbols.count) unique symbols (\(dupCount) duplicate-or-suffix-variant)")
        }

        let quotes = try await backendService.fetchBatchQuotes(symbols: symbols)

        for quote in quotes {
            let key = quote.symbol.normalizedTicker
            guard let matches = holdingsByNormalized[key] else { continue }
            for holding in matches {
                if let price = quote.price {
                    holding.currentPrice = price.decimalAmount
                }
                holding.lastPriceUpdate = .now
                if let dy = quote.dividendYieldDecimal, dy > 0 {
                    holding.dividendYield = dy
                }
            }
        }
    }

    /// Background dividend pull, gated to once per calendar day. The backend
    /// cron only refreshes upstream dividend records on tue/fri, so re-pulling
    /// more than daily just no-ops the dedup loop. Silent on failure — the
    /// manual refresh button on `AssetClassDividendsView` is the recovery
    /// path, and the on-Contribution scrape covers brand-new tickers.
    func syncDividendsIfStale(modelContext: ModelContext, backendService: any BackendServiceProtocol) async {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: Self.lastDividendSyncKey) as? Date,
           Calendar.current.isDateInToday(last) {
            print("[Sync] syncDividendsIfStale: skipped — already synced today at \(last)")
            return
        }
        print("[Sync] syncDividendsIfStale: gate open, pulling")
        do {
            try await syncDividends(modelContext: modelContext, backendService: backendService)
            try modelContext.save()
            defaults.set(Date(), forKey: Self.lastDividendSyncKey)
            print("[Sync] syncDividendsIfStale: done, gate stamp updated")
        } catch {
            print("[Sync] syncDividendsIfStale: failed — \(error.localizedDescription)")
        }
    }

    /// Fetch dividend history for all local holdings.
    ///
    /// Holdings are grouped by `normalizedTicker` so each unique asset is
    /// requested once. When the backend returns rows for a symbol, the new
    /// `DividendPayment` is fanned out to every local holding sharing that
    /// normalized ticker (e.g. suffix variants). Per-holding dedupe key
    /// prevents re-inserts on subsequent syncs.
    func syncDividends(modelContext: ModelContext, backendService: any BackendServiceProtocol) async throws {
        let start = Date()
        let holdingDescriptor = FetchDescriptor<Holding>()
        let holdings = try modelContext.fetch(holdingDescriptor).filter { !$0.isCustom }
        guard !holdings.isEmpty else {
            print("[Dividends] syncDividends: no non-custom holdings, skipping")
            return
        }

        var holdingsByNormalized: [String: [Holding]] = [:]
        for h in holdings {
            holdingsByNormalized[h.ticker.normalizedTicker, default: []].append(h)
        }
        let symbols = Array(holdingsByNormalized.keys).sorted()
        let dupCount = holdings.count - symbols.count
        print("[Dividends] syncDividends: \(holdings.count) holdings → \(symbols.count) unique symbols (\(dupCount) duplicate-or-suffix-variant)")
        print("[Dividends] syncDividends: requesting → \(symbols.joined(separator: ","))")

        let dividends = try await backendService.fetchDividendsForSymbols(symbols: symbols, year: nil)
        print("[Dividends] syncDividends: backend returned \(dividends.count) rows")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Per-holding existing keys: `(holding.persistentModelID, exDate)`.
        let existingDivDescriptor = FetchDescriptor<DividendPayment>()
        let existingDivs = try modelContext.fetch(existingDivDescriptor)
        var existingKeys = Set<String>()
        for div in existingDivs {
            guard let h = div.holding else { continue }
            let key = "\(h.persistentModelID)-\(div.exDate.timeIntervalSince1970)"
            existingKeys.insert(key)
        }
        print("[Dividends] syncDividends: \(existingDivs.count) existing local rows")

        var inserted = 0
        var skippedUnknownSymbol = 0
        var skippedBadDate = 0
        var skippedDuplicate = 0
        var insertedByTicker: [String: Int] = [:]

        for item in dividends {
            let normalized = item.symbol.normalizedTicker
            guard let matches = holdingsByNormalized[normalized] else {
                skippedUnknownSymbol += 1
                continue
            }

            let dateStr = item.paymentDate ?? item.exDate
            guard let paymentDate = formatter.date(from: dateStr) else {
                skippedBadDate += 1
                continue
            }
            let exDate = formatter.date(from: item.exDate) ?? paymentDate

            for holding in matches {
                let key = "\(holding.persistentModelID)-\(exDate.timeIntervalSince1970)"
                guard !existingKeys.contains(key) else {
                    skippedDuplicate += 1
                    continue
                }
                existingKeys.insert(key)

                let dividend = DividendPayment(
                    exDate: exDate,
                    paymentDate: paymentDate,
                    amountPerShare: item.value.decimalAmount,
                    taxTreatment: holding.assetClass.defaultTaxTreatment
                )
                dividend.holding = holding
                modelContext.insert(dividend)

                inserted += 1
                insertedByTicker[normalized, default: 0] += 1
                print("[Dividends] inserted \(normalized) → holding.id=\(holding.persistentModelID) ex=\(item.exDate) pay=\(item.paymentDate ?? "nil") amt=\(item.value.decimalAmount)")
            }
        }

        let elapsed = String(format: "%.2f", Date().timeIntervalSince(start))
        print("[Dividends] syncDividends done in \(elapsed)s — inserted \(inserted), dup \(skippedDuplicate), unknown-symbol \(skippedUnknownSymbol), bad-date \(skippedBadDate)")
        if !insertedByTicker.isEmpty {
            print("[Dividends] inserted breakdown: \(insertedByTicker)")
        }
    }
}
