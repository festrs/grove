import Foundation

actor MockBackendService: BackendServiceProtocol {

    func searchStocks(query: String) async throws -> [StockSearchResultDTO] {
        [
            StockSearchResultDTO(id: "ITUB3.SA", symbol: "ITUB3.SA", name: "ITAU UNIBANCO HOLDING S.A.", type: "stock", price: "46.37", currency: "BRL", change: "-0.92", sector: "Finance", logo: nil),
            StockSearchResultDTO(id: "PETR4.SA", symbol: "PETR4.SA", name: "PETROLEO BRASILEIRO S.A. PETROBRAS", type: "stock", price: "36.80", currency: "BRL", change: "1.5", sector: "Energy Minerals", logo: nil),
            StockSearchResultDTO(id: "AAPL", symbol: "AAPL", name: "Apple Inc", type: "Common Stock", price: "189.50", currency: "USD", change: "0.3", sector: nil, logo: nil),
        ].filter { $0.symbol.lowercased().contains(query.lowercased()) || ($0.name ?? "").lowercased().contains(query.lowercased()) }
    }

    func fetchStockQuote(symbol: String) async throws -> StockQuoteDTO {
        StockQuoteDTO(symbol: symbol, name: symbol, price: MoneyDTO(amount: "32.50", currency: "BRL"), currency: "BRL", marketCap: nil)
    }

    func fetchBatchQuotes(symbols: [String]) async throws -> [BatchQuoteDTO] {
        symbols.map { BatchQuoteDTO(symbol: $0, name: $0, price: MoneyDTO(amount: "32.50", currency: "BRL"), currency: "BRL") }
    }

    func fetchExchangeRate(pair: String) async throws -> BackendExchangeRateDTO {
        BackendExchangeRateDTO(pair: pair, rate: 5.12)
    }

    func fetchDividendsForSymbols(symbols: [String], year: Int?) async throws -> [MobileDividendDTO] {
        []
    }

    func fetchDividendSummary(symbols: [String]) async throws -> [String: DividendSummaryDTO] {
        [:]
    }

    func trackSymbol(symbol: String, assetClass: String) async throws {}
    func untrackSymbol(symbol: String) async throws {}
    func syncTrackedSymbols(pairs: [(symbol: String, assetClass: String)]) async throws {}
}
