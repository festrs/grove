import Testing
import Foundation
import SwiftData
import GroveDomain
@testable import Grove

@Suite(.serialized)
struct AssetClassDividendsViewModelTests {

    // MARK: - Initial state

    @MainActor
    @Test func initialState() {
        let vm = AssetClassDividendsViewModel()
        #expect(vm.isRefreshing == false)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - refresh: argument forwarding

    @MainActor
    @Test func refreshForwardsSymbolsAndAssetClassToBackend() async throws {
        let ctx = try makeTestContext()
        let backend = RecordingBackend()
        let sync = SyncService()
        let vm = AssetClassDividendsViewModel()

        await vm.refresh(
            symbols: ["HGLG11", "KNRI11"],
            assetClass: .fiis,
            modelContext: ctx,
            backendService: backend,
            syncService: sync
        )

        let calls = await backend.refreshCalls
        #expect(calls.count == 1)
        #expect(calls.first?.symbols == ["HGLG11", "KNRI11"])
        #expect(calls.first?.assetClass == "fiis")
        #expect(calls.first?.since == nil, "Manual refresh must leave since unset so users can backfill full history")
        #expect(vm.errorMessage == nil)
    }

    // MARK: - refresh: empty symbols is a no-op

    @MainActor
    @Test func refreshIsNoOpWhenSymbolsEmpty() async throws {
        let ctx = try makeTestContext()
        let backend = RecordingBackend()
        let sync = SyncService()
        let vm = AssetClassDividendsViewModel()

        await vm.refresh(
            symbols: [],
            assetClass: .fiis,
            modelContext: ctx,
            backendService: backend,
            syncService: sync
        )

        let calls = await backend.refreshCalls
        #expect(calls.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - refresh: failure path

    @MainActor
    @Test func refreshSetsErrorWhenBackendFails() async throws {
        let ctx = try makeTestContext()
        let backend = FailingBackend()
        let sync = SyncService()
        let vm = AssetClassDividendsViewModel()

        await vm.refresh(
            symbols: ["HGLG11"],
            assetClass: .fiis,
            modelContext: ctx,
            backendService: backend,
            syncService: sync
        )

        #expect(vm.errorMessage != nil)
        #expect(vm.isRefreshing == false)
    }

    // MARK: - refresh: clears stale error on subsequent success

    @MainActor
    @Test func refreshClearsErrorOnSuccess() async throws {
        let ctx = try makeTestContext()
        let sync = SyncService()
        let vm = AssetClassDividendsViewModel()

        // Seed an error from a previous failed run.
        vm.errorMessage = "old error"

        let backend = RecordingBackend()
        await vm.refresh(
            symbols: ["HGLG11"],
            assetClass: .fiis,
            modelContext: ctx,
            backendService: backend,
            syncService: sync
        )

        #expect(vm.errorMessage == nil)
    }
}

// MARK: - Test doubles

private actor RecordingBackend: BackendServiceProtocol {
    struct RefreshCall: Equatable {
        let symbols: [String]
        let assetClass: String
        let since: Date?
    }
    var refreshCalls: [RefreshCall] = []

    func searchStocks(query: String, assetClass: AssetClassType?) async throws -> [StockSearchResultDTO] { [] }
    func fetchStockQuote(symbol: String) async throws -> StockQuoteDTO {
        StockQuoteDTO(symbol: symbol, name: symbol, price: MoneyDTO(amount: "0", currency: "BRL"), currency: "BRL")
    }
    func fetchBatchQuotes(symbols: [String]) async throws -> [BatchQuoteDTO] { [] }
    func fetchExchangeRate(pair: String) async throws -> BackendExchangeRateDTO {
        BackendExchangeRateDTO(pair: pair, rate: 5)
    }
    func fetchDividendsForSymbols(symbols: [String], year: Int?) async throws -> [MobileDividendDTO] { [] }
    func refreshDividends(symbols: [String], assetClass: String, since: Date?) async throws -> DividendRefreshResultDTO {
        refreshCalls.append(.init(symbols: symbols, assetClass: assetClass, since: since))
        return DividendRefreshResultDTO(scraped: symbols.count, newRecords: 0, failed: [])
    }
    func trackSymbol(symbol: String, assetClass: String) async throws {}
    func untrackSymbol(symbol: String) async throws {}
    func syncTrackedSymbols(pairs: [(symbol: String, assetClass: String)]) async throws {}
    func fetchPriceHistory(symbol: String, period: String) async throws -> [PriceHistoryPointDTO] { [] }
    func fetchFundamentals(symbol: String) async throws -> FundamentalsDTO {
        FundamentalsDTO(
            symbol: symbol,
            ipoYears: nil, ipoRating: nil,
            epsGrowthPct: nil, epsRating: nil,
            currentNetDebtEbitda: nil, highDebtYearsPct: nil, debtRating: nil,
            profitableYearsPct: nil, profitRating: nil,
            compositeScore: nil, updatedAt: nil
        )
    }
    func importPortfolio(fileData: Data, filename: String) async throws -> [ImportedPosition] { [] }
}

private actor FailingBackend: BackendServiceProtocol {
    enum TestError: Error, LocalizedError {
        case refreshFailed
        var errorDescription: String? { "refresh failed" }
    }

    func searchStocks(query: String, assetClass: AssetClassType?) async throws -> [StockSearchResultDTO] { [] }
    func fetchStockQuote(symbol: String) async throws -> StockQuoteDTO {
        StockQuoteDTO(symbol: symbol, name: symbol, price: MoneyDTO(amount: "0", currency: "BRL"), currency: "BRL")
    }
    func fetchBatchQuotes(symbols: [String]) async throws -> [BatchQuoteDTO] { [] }
    func fetchExchangeRate(pair: String) async throws -> BackendExchangeRateDTO {
        BackendExchangeRateDTO(pair: pair, rate: 5)
    }
    func fetchDividendsForSymbols(symbols: [String], year: Int?) async throws -> [MobileDividendDTO] { [] }
    func refreshDividends(symbols: [String], assetClass: String, since: Date?) async throws -> DividendRefreshResultDTO {
        throw TestError.refreshFailed
    }
    func trackSymbol(symbol: String, assetClass: String) async throws {}
    func untrackSymbol(symbol: String) async throws {}
    func syncTrackedSymbols(pairs: [(symbol: String, assetClass: String)]) async throws {}
    func fetchPriceHistory(symbol: String, period: String) async throws -> [PriceHistoryPointDTO] { [] }
    func fetchFundamentals(symbol: String) async throws -> FundamentalsDTO {
        FundamentalsDTO(
            symbol: symbol,
            ipoYears: nil, ipoRating: nil,
            epsGrowthPct: nil, epsRating: nil,
            currentNetDebtEbitda: nil, highDebtYearsPct: nil, debtRating: nil,
            profitableYearsPct: nil, profitRating: nil,
            compositeScore: nil, updatedAt: nil
        )
    }
    func importPortfolio(fileData: Data, filename: String) async throws -> [ImportedPosition] { [] }
}
