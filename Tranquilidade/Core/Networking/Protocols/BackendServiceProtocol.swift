import Foundation

/// Backend provides market data only. Portfolio lives in SwiftData.
protocol BackendServiceProtocol: Sendable {
    // Stocks
    func searchStocks(query: String) async throws -> [StockSearchResultDTO]
    func fetchStockQuote(symbol: String) async throws -> StockQuoteDTO

    // Batch quotes (send local symbols, get prices back)
    func fetchBatchQuotes(symbols: [String]) async throws -> [BatchQuoteDTO]

    // Exchange rate
    func fetchExchangeRate(pair: String) async throws -> BackendExchangeRateDTO

    // Dividends (send local symbols, get dividend data back)
    func fetchDividendsForSymbols(symbols: [String], year: Int?) async throws -> [MobileDividendDTO]
    func fetchDividendSummary(symbols: [String]) async throws -> [String: DividendSummaryDTO]

    // Symbol tracking (tell backend which symbols to keep fresh)
    func trackSymbol(symbol: String, assetClass: String) async throws
    func untrackSymbol(symbol: String) async throws
    func syncTrackedSymbols(pairs: [(symbol: String, assetClass: String)]) async throws
}
