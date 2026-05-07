import Foundation
import GroveDomain

actor MockBackendService: BackendServiceProtocol {

    func searchStocks(query: String, assetClass: AssetClassType?) async throws -> [StockSearchResultDTO] {
        let all = [
            StockSearchResultDTO(id: "ITUB3.SA", symbol: "ITUB3.SA", name: "ITAU UNIBANCO HOLDING S.A.", type: "stock", price: MoneyDTO(amount: "46.37", currency: "BRL"), currency: "BRL", change: -0.92, sector: "Finance", logo: nil),
            StockSearchResultDTO(
                id: "PETR4.SA",
                symbol: "PETR4.SA",
                name: "PETROLEO BRASILEIRO S.A. PETROBRAS",
                type: "stock",
                price: MoneyDTO(amount: "36.80", currency: "BRL"),
                currency: "BRL",
                change: 1.5,
                sector: "Energy Minerals",
                logo: nil
            ),
            StockSearchResultDTO(id: "AAPL", symbol: "AAPL", name: "Apple Inc", type: "Common Stock", price: MoneyDTO(amount: "189.50", currency: "USD"), currency: "USD", change: 0.3, sector: nil, logo: nil),
        ]
        let matched = all.filter { $0.symbol.lowercased().contains(query.lowercased()) || ($0.name ?? "").lowercased().contains(query.lowercased()) }
        guard let assetClass else { return matched }
        return matched.filter { $0.inferredAssetClass == assetClass }
    }

    func fetchStockQuote(symbol: String) async throws -> StockQuoteDTO {
        StockQuoteDTO(symbol: symbol, name: symbol, price: MoneyDTO(amount: "32.50", currency: "BRL"), currency: "BRL", marketCap: nil)
    }

    func fetchBatchQuotes(symbols: [String]) async throws -> [BatchQuoteDTO] {
        symbols.map {
            BatchQuoteDTO(
                symbol: $0,
                name: $0,
                price: MoneyDTO(amount: "32.50", currency: "BRL"),
                currency: "BRL",
                dividendYield: "6.50"
            )
        }
    }

    func fetchExchangeRate(pair: String) async throws -> BackendExchangeRateDTO {
        BackendExchangeRateDTO(pair: pair, rate: 5.12)
    }

    func fetchDividendsForSymbols(symbols: [String], year: Int?) async throws -> [MobileDividendDTO] {
        []
    }

    func refreshDividends(symbols: [String], assetClass: String, since: Date?) async throws -> DividendRefreshResultDTO {
        DividendRefreshResultDTO(scraped: symbols.count, newRecords: 0, failed: [])
    }

    func trackSymbol(symbol: String, assetClass: String) async throws {}
    func untrackSymbol(symbol: String) async throws {}
    func syncTrackedSymbols(pairs: [(symbol: String, assetClass: String)]) async throws {}

    func fetchPriceHistory(symbol: String, period: String) async throws -> [PriceHistoryPointDTO] {
        [
            PriceHistoryPointDTO(date: "2026-04-21", price: MoneyDTO(amount: "32.00", currency: "BRL")),
            PriceHistoryPointDTO(date: "2026-04-22", price: MoneyDTO(amount: "32.50", currency: "BRL")),
            PriceHistoryPointDTO(date: "2026-04-23", price: MoneyDTO(amount: "33.10", currency: "BRL")),
        ]
    }

    func fetchFundamentals(symbol: String) async throws -> FundamentalsDTO {
        FundamentalsDTO(
            symbol: symbol,
            ipoYears: 20,
            ipoRating: "A",
            epsGrowthPct: 12.5,
            epsRating: "B",
            currentNetDebtEbitda: 1.8,
            highDebtYearsPct: 10.0,
            debtRating: "A",
            profitableYearsPct: 95.0,
            profitRating: "A",
            compositeScore: 8.5,
            updatedAt: "2026-04-23T10:00:00"
        )
    }

    func importPortfolio(fileData: Data, filename: String) async throws -> [ImportedPosition] {
        []
    }
}
