import Foundation
import SwiftData

@Observable
final class SyncService {
    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: String?

    /// Sync market data: send local symbols to backend, update prices and dividends
    func syncAll(modelContext: ModelContext, backendService: any BackendServiceProtocol) async {
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            try await syncTrackedSymbols(modelContext: modelContext, backendService: backendService)
            try await syncPrices(modelContext: modelContext, backendService: backendService)
            try modelContext.save()
            try await syncDividends(modelContext: modelContext, backendService: backendService)
            try modelContext.save()
            lastSyncDate = .now
        } catch {
            syncError = error.localizedDescription
        }
    }

    /// Tell backend which symbols the app cares about
    private func syncTrackedSymbols(modelContext: ModelContext, backendService: any BackendServiceProtocol) async throws {
        let descriptor = FetchDescriptor<Holding>()
        let holdings = try modelContext.fetch(descriptor)
        guard !holdings.isEmpty else { return }

        let pairs = holdings.map { (symbol: $0.ticker, assetClass: $0.assetClass.rawValue) }
        try await backendService.syncTrackedSymbols(pairs: pairs)
    }

    /// Fetch latest prices for all local holdings
    func syncPrices(modelContext: ModelContext, backendService: any BackendServiceProtocol) async throws {
        let descriptor = FetchDescriptor<Holding>()
        let holdings = try modelContext.fetch(descriptor)
        guard !holdings.isEmpty else { return }

        let symbols = holdings.map(\.ticker)
        let quotes = try await backendService.fetchBatchQuotes(symbols: symbols)

        // Also fetch DY data
        let dySummary = try await backendService.fetchDividendSummary(symbols: symbols)

        // Update local holdings
        for holding in holdings {
            if let quote = quotes.first(where: { $0.symbol == holding.ticker }) {
                if let price = quote.price {
                    holding.currentPrice = price.decimalAmount
                }
                holding.lastPriceUpdate = .now
            }

            if let dy = dySummary[holding.ticker] {
                let annualDPS = dy.decimalValue
                if holding.currentPrice > 0 && annualDPS > 0 {
                    holding.dividendYield = (annualDPS / holding.currentPrice) * 100
                }
            }
        }
    }

    /// Fetch dividend history for all local holdings
    func syncDividends(modelContext: ModelContext, backendService: any BackendServiceProtocol) async throws {
        let holdingDescriptor = FetchDescriptor<Holding>()
        let holdings = try modelContext.fetch(holdingDescriptor)
        guard !holdings.isEmpty else { return }

        let symbols = holdings.map(\.ticker)
        var holdingByTicker: [String: Holding] = [:]
        for h in holdings {
            holdingByTicker[h.ticker] = h
        }

        let dividends = try await backendService.fetchDividendsForSymbols(symbols: symbols, year: nil)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Build set of existing dividend keys
        let existingDivDescriptor = FetchDescriptor<DividendPayment>()
        let existingDivs = try modelContext.fetch(existingDivDescriptor)
        var existingKeys = Set<String>()
        for div in existingDivs {
            let key = "\(div.holding?.ticker ?? "")-\(div.exDate.timeIntervalSince1970)"
            existingKeys.insert(key)
        }

        var newPayments: [(ticker: String, amount: Decimal, date: Date)] = []

        for item in dividends {
            guard let holding = holdingByTicker[item.symbol] else { continue }

            let dateStr = item.paymentDate ?? item.exDate
            guard let paymentDate = formatter.date(from: dateStr) else { continue }
            let exDate = formatter.date(from: item.exDate) ?? paymentDate

            let key = "\(holding.ticker)-\(exDate.timeIntervalSince1970)"
            guard !existingKeys.contains(key) else { continue }
            existingKeys.insert(key)

            let dividend = DividendPayment(
                exDate: exDate,
                paymentDate: paymentDate,
                amountPerShare: item.value.decimalAmount,
                quantity: holding.quantity,
                taxTreatment: holding.assetClass.defaultTaxTreatment
            )
            dividend.holding = holding
            modelContext.insert(dividend)

            newPayments.append((ticker: holding.ticker, amount: dividend.netAmount, date: paymentDate))
        }

        // TODO: Enable when push notifications are ready
        // if !newPayments.isEmpty {
        //     await NotificationCoordinator.handleNewDividends(newPayments)
        // }
    }
}
