import Foundation
import GroveDomain

/// Backend provides market data only. Portfolio lives in SwiftData.
protocol BackendServiceProtocol: Sendable {
    // Stocks
    func searchStocks(query: String, assetClass: AssetClassType?) async throws -> [StockSearchResultDTO]
    func fetchStockQuote(symbol: String) async throws -> StockQuoteDTO

    // Batch quotes (send local symbols, get prices back)
    func fetchBatchQuotes(symbols: [String]) async throws -> [BatchQuoteDTO]

    // Exchange rate
    func fetchExchangeRate(pair: String) async throws -> BackendExchangeRateDTO

    // Dividends (send local symbols, get dividend data back)
    func fetchDividendsForSymbols(symbols: [String], year: Int?) async throws -> [MobileDividendDTO]

    // On-demand dividend scrape: ask the backend to fetch fresh dividend
    // history for these symbols inline (vs waiting for the next cron tick).
    // Caller should refetch `fetchDividendsForSymbols` afterwards. Pass
    // `since` (the holding's first-Contribution date) on the auto-bootstrap
    // path so we don't pull payments from before the user owned the asset;
    // omit it for the manual refresh button to allow full backfills.
    func refreshDividends(symbols: [String], assetClass: String, since: Date?) async throws -> DividendRefreshResultDTO

    // Symbol tracking (tell backend which symbols to keep fresh)
    func trackSymbol(symbol: String, assetClass: String) async throws
    func untrackSymbol(symbol: String) async throws
    func syncTrackedSymbols(pairs: [(symbol: String, assetClass: String)]) async throws

    // Price history
    func fetchPriceHistory(symbol: String, period: String) async throws -> [PriceHistoryPointDTO]

    // Fundamentals
    func fetchFundamentals(symbol: String) async throws -> FundamentalsDTO

    // Import portfolio (file → parsed positions)
    func importPortfolio(fileData: Data, filename: String) async throws -> [ImportedPosition]
}
