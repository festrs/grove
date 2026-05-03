import Foundation
import GroveDomain

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

    func searchStocks(query: String, assetClass: AssetClassType?) async throws -> [StockSearchResultDTO] {
        var items = [URLQueryItem(name: "q", value: query)]
        if let assetClass {
            items.append(URLQueryItem(name: "asset_class", value: assetClass.rawValue))
        }
        let url = try buildURL(path: "/stocks/search", queryItems: items)
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

    func refreshDividends(symbols: [String], assetClass: String, since: Date?) async throws -> DividendRefreshResultDTO {
        guard !symbols.isEmpty else {
            return DividendRefreshResultDTO(scraped: 0, newRecords: 0, failed: [])
        }
        var queryItems = [
            URLQueryItem(name: "symbols", value: symbols.joined(separator: ",")),
            URLQueryItem(name: "asset_class", value: assetClass),
        ]
        if let since {
            queryItems.append(URLQueryItem(name: "since", value: Self.dateFormatter.string(from: since)))
        }
        let url = try buildURL(path: "/mobile/dividends/refresh", queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Backend serially hits upstream providers with a per-symbol delay,
        // so a 20-symbol refresh can take 40s+. Bump the timeout accordingly.
        request.timeoutInterval = 90
        for (key, value) in apiHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            throw APIError.networkError(urlError)
        } catch {
            throw APIError.unknown(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(200) ?? ""
            let hint: String
            switch status {
            case 404, 405:
                hint = "Endpoint missing — backend container probably needs rebuild (just backend)."
            case 422:
                hint = "Backend rejected the request payload."
            case 429:
                hint = "Rate-limited — wait a minute and try again."
            case 500...599:
                hint = "Backend error — provider scrape may have failed."
            default:
                hint = ""
            }
            let detail = hint.isEmpty ? "" : " \(hint)"
            throw APIError.unknown("Refresh dividends HTTP \(status).\(detail) Body: \(body)")
        }
        return try JSONDecoder().decode(DividendRefreshResultDTO.self, from: data)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Symbol Tracking

    func trackSymbol(symbol: String, assetClass: String) async throws {
        let url = try buildURL(path: "/mobile/track", queryItems: [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "asset_class", value: assetClass),
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        for (key, value) in apiHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let response: URLResponse
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            throw APIError.networkError(urlError)
        } catch {
            throw APIError.unknown(error.localizedDescription)
        }

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
        request.timeoutInterval = 30
        for (key, value) in apiHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let response: URLResponse
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            throw APIError.networkError(urlError)
        } catch {
            throw APIError.unknown(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.unknown("Failed to sync tracked symbols")
        }
    }

    // MARK: - Price History

    func fetchPriceHistory(symbol: String, period: String) async throws -> [PriceHistoryPointDTO] {
        let url = try buildURL(path: "/stocks/\(symbol)/history", queryItems: [
            URLQueryItem(name: "period", value: period)
        ])
        return try await HTTPClient.fetch(url: url, headers: apiHeaders)
    }

    // MARK: - Fundamentals

    func fetchFundamentals(symbol: String) async throws -> FundamentalsDTO {
        let url = try buildURL(path: "/mobile/fundamentals/\(symbol)")
        return try await HTTPClient.fetch(url: url, headers: apiHeaders)
    }

    // MARK: - Import Portfolio

    func importPortfolio(fileData: Data?, filename: String?, text: String?) async throws -> [ImportedPosition] {
        let url = try buildURL(path: "/mobile/import/parse")
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        for (key, value) in apiHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        var body = Data()

        if let fileData, let filename {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8))
            body.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
            body.append(fileData)
            body.append(Data("\r\n".utf8))
        }

        if let text, !text.isEmpty {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"text\"\r\n\r\n".utf8))
            body.append(Data(text.utf8))
            body.append(Data("\r\n".utf8))
        }

        body.append(Data("--\(boundary)--\r\n".utf8))
        request.httpBody = body

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            throw APIError.networkError(urlError)
        } catch {
            throw APIError.unknown(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown("Resposta invalida do servidor.")
        }

        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode)
        }

        let parsed = try JSONDecoder().decode(ImportParseResponse.self, from: data)
        return parsed.positions
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
