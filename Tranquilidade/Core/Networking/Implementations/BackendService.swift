import Foundation

actor BackendService: BackendServiceProtocol {

    private let baseURL: String

    private var apiHeaders: [String: String] {
        [
            "X-API-Key": Secrets.mobileAPIKey,
            "X-Device-ID": DeviceIdentifier.current,
        ]
    }

    init() {
        self.baseURL = AppConstants.API.backendBaseURL
    }

    // MARK: - Stocks (existing public endpoints)

    func searchStocks(query: String) async throws -> [StockSearchResultDTO] {
        let url = try buildURL(path: "/stocks/search", queryItems: [
            URLQueryItem(name: "q", value: query)
        ])
        return try await HTTPClient.fetch(url: url, headers: apiHeaders)
    }

    func fetchStockQuote(symbol: String) async throws -> StockQuoteDTO {
        let url = try buildURL(path: "/stocks/\(symbol)")
        return try await HTTPClient.fetch(url: url, headers: apiHeaders)
    }

    // MARK: - Batch Quotes (mobile endpoint)

    func fetchBatchQuotes(symbols: [String]) async throws -> [BatchQuoteDTO] {
        guard !symbols.isEmpty else { return [] }
        let url = try buildURL(path: "/mobile/quotes", queryItems: [
            URLQueryItem(name: "symbols", value: symbols.joined(separator: ","))
        ])
        let response: BatchQuotesResponse = try await HTTPClient.fetch(url: url, headers: apiHeaders)
        return response.quotes
    }

    // MARK: - Exchange Rate (mobile endpoint)

    func fetchExchangeRate(pair: String) async throws -> BackendExchangeRateDTO {
        let url = try buildURL(path: "/mobile/exchange-rate", queryItems: [
            URLQueryItem(name: "pair", value: pair)
        ])
        return try await HTTPClient.fetch(url: url, headers: apiHeaders)
    }

    // MARK: - Dividends (mobile endpoints)

    func fetchDividendsForSymbols(symbols: [String], year: Int?) async throws -> [MobileDividendDTO] {
        guard !symbols.isEmpty else { return [] }
        var queryItems = [URLQueryItem(name: "symbols", value: symbols.joined(separator: ","))]
        if let year { queryItems.append(URLQueryItem(name: "year", value: "\(year)")) }
        let url = try buildURL(path: "/mobile/dividends", queryItems: queryItems)
        return try await HTTPClient.fetch(url: url, headers: apiHeaders)
    }

    func fetchDividendSummary(symbols: [String]) async throws -> [String: DividendSummaryDTO] {
        guard !symbols.isEmpty else { return [:] }
        let url = try buildURL(path: "/mobile/dividends/summary", queryItems: [
            URLQueryItem(name: "symbols", value: symbols.joined(separator: ","))
        ])
        return try await HTTPClient.fetch(url: url, headers: apiHeaders)
    }

    // MARK: - Symbol Tracking

    func trackSymbol(symbol: String, assetClass: String) async throws {
        let url = try buildURL(path: "/mobile/track", queryItems: [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "asset_class", value: assetClass),
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in apiHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.unknown("Failed to track symbol")
        }
    }

    func untrackSymbol(symbol: String) async throws {
        // No-op: symbols are shared across users, never removed
    }

    func syncTrackedSymbols(pairs: [(symbol: String, assetClass: String)]) async throws {
        guard !pairs.isEmpty else { return }
        let joined = pairs.map { "\($0.symbol):\($0.assetClass)" }.joined(separator: ",")
        let url = try buildURL(path: "/mobile/track/sync", queryItems: [
            URLQueryItem(name: "symbols", value: joined),
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in apiHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.unknown("Failed to sync tracked symbols")
        }
    }

    // MARK: - Private

    private func buildURL(path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        var components = URLComponents(string: "\(baseURL)\(path)")
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw APIError.unknown("URL invalida: \(path)")
        }
        return url
    }
}
