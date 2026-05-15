import Foundation
import GroveDomain

actor BackendService: BackendServiceProtocol {

    /// Backend caps every multi-symbol query at 50 (`MAX_SYMBOLS_PER_REQUEST`
    /// in `routers/mobile.py`). We chunk client-side and merge results so
    /// callers stay symbol-count-agnostic.
    private static let batchChunkSize = 50

    /// `/dividends/refresh` is stricter (`MAX_REFRESH_SYMBOLS = 20`) because
    /// the backend hits upstream providers serially with a per-symbol delay.
    private static let refreshChunkSize = 20

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
        let chunks = symbols.chunked(into: Self.batchChunkSize)
        if chunks.count > 1 {
            print("[Net] GET /mobile/quotes — \(symbols.count) symbols across \(chunks.count) chunk(s)")
        }
        let headers = apiHeaders
        return try await withThrowingTaskGroup(of: [BatchQuoteDTO].self) { group in
            for chunk in chunks {
                let url = try self.buildURL(path: "/mobile/quotes", queryItems: [
                    URLQueryItem(name: "symbols", value: chunk.joined(separator: ","))
                ])
                group.addTask {
                    let response: BatchQuotesResponse = try await HTTPClient.fetch(url: url, headers: headers)
                    return response.quotes
                }
            }
            var merged: [BatchQuoteDTO] = []
            for try await part in group { merged.append(contentsOf: part) }
            return merged
        }
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
        let chunks = symbols.chunked(into: Self.batchChunkSize)
        let start = Date()
        print("[Net] GET /mobile/dividends — \(symbols.count) symbols across \(chunks.count) chunk(s)")
        let headers = apiHeaders
        do {
            let merged = try await withThrowingTaskGroup(of: [MobileDividendDTO].self) { group in
                for chunk in chunks {
                    var queryItems = [URLQueryItem(name: "symbols", value: chunk.joined(separator: ","))]
                    if let year { queryItems.append(URLQueryItem(name: "year", value: "\(year)")) }
                    let url = try self.buildURL(path: "/mobile/dividends", queryItems: queryItems)
                    group.addTask {
                        try await HTTPClient.fetch(url: url, headers: headers)
                    }
                }
                var all: [MobileDividendDTO] = []
                for try await part in group { all.append(contentsOf: part) }
                return all
            }
            print("[Net] GET /mobile/dividends → \(merged.count) rows in \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
            return merged
        } catch {
            print("[Net] GET /mobile/dividends FAILED in \(String(format: "%.2f", Date().timeIntervalSince(start)))s — \(error.localizedDescription)")
            throw error
        }
    }

    func refreshDividends(symbols: [String], assetClass: String, since: Date?) async throws -> DividendRefreshResultDTO {
        guard !symbols.isEmpty else {
            return DividendRefreshResultDTO(scraped: 0, newRecords: 0, failed: [])
        }
        let chunks = symbols.chunked(into: Self.refreshChunkSize)
        let start = Date()
        print("[Net] POST /mobile/dividends/refresh — \(symbols.count) symbols across \(chunks.count) chunk(s) (limit \(Self.refreshChunkSize)/chunk)")
        let merged = try await withThrowingTaskGroup(of: DividendRefreshResultDTO.self) { group in
            for chunk in chunks {
                group.addTask {
                    try await self.refreshDividendsChunk(symbols: chunk, assetClass: assetClass, since: since)
                }
            }
            var scraped = 0
            var newRecords = 0
            var failed: [String] = []
            for try await part in group {
                scraped += part.scraped
                newRecords += part.newRecords
                failed.append(contentsOf: part.failed)
            }
            return DividendRefreshResultDTO(scraped: scraped, newRecords: newRecords, failed: failed)
        }
        let elapsed = String(format: "%.2f", Date().timeIntervalSince(start))
        print("[Net] POST /mobile/dividends/refresh merged in \(elapsed)s — scraped=\(merged.scraped) new=\(merged.newRecords) failed=\(merged.failed)")
        return merged
    }

    private func refreshDividendsChunk(symbols: [String], assetClass: String, since: Date?) async throws -> DividendRefreshResultDTO {
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
        // so a 20-symbol chunk can take 40s+. Bump the timeout accordingly.
        request.timeoutInterval = 90
        for (key, value) in apiHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let start = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            print("[Net] POST /refresh chunk(\(symbols.count)) URLError in \(String(format: "%.2f", Date().timeIntervalSince(start)))s — \(urlError.localizedDescription) code=\(urlError.code.rawValue)")
            throw APIError.networkError(urlError)
        } catch {
            print("[Net] POST /refresh chunk(\(symbols.count)) failed in \(String(format: "%.2f", Date().timeIntervalSince(start)))s — \(error.localizedDescription)")
            throw APIError.unknown(error.localizedDescription)
        }

        let elapsed = String(format: "%.2f", Date().timeIntervalSince(start))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(200) ?? ""
            print("[Net] POST /refresh chunk(\(symbols.count)) HTTP \(status) in \(elapsed)s — body=\(body)")
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
        let decoded = try JSONDecoder().decode(DividendRefreshResultDTO.self, from: data)
        print("[Net] POST /refresh chunk(\(symbols.count)) 200 in \(elapsed)s — scraped=\(decoded.scraped) new=\(decoded.newRecords) failed=\(decoded.failed)")
        return decoded
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
        let chunks = pairs.chunked(into: Self.batchChunkSize)
        if chunks.count > 1 {
            print("[Net] POST /mobile/track/sync — \(pairs.count) pairs across \(chunks.count) chunk(s)")
        }
        let headers = apiHeaders
        try await withThrowingTaskGroup(of: Void.self) { group in
            for chunk in chunks {
                let joined = chunk.map { "\($0.symbol):\($0.assetClass)" }.joined(separator: ",")
                let url = try self.buildURL(path: "/mobile/track/sync", queryItems: [
                    URLQueryItem(name: "symbols", value: joined),
                ])
                group.addTask {
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 30
                    for (key, value) in headers {
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
            }
            try await group.waitForAll()
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

    func importPortfolio(fileData: Data, filename: String) async throws -> [ImportedPosition] {
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
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n".utf8))
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

    // MARK: - Redeem

    func redeemCode(_ code: String) async throws -> RedeemCodeResultDTO {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return RedeemCodeResultDTO(valid: false, unlocks: [])
        }
        let url = try buildURL(path: "/mobile/redeem", queryItems: [
            URLQueryItem(name: "code", value: trimmed)
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
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

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown("Invalid server response.")
        }
        // 422 = malformed code (treat as invalid for the UI rather than
        // throwing — user gets a clean "code not recognised" message).
        if http.statusCode == 422 {
            return RedeemCodeResultDTO(valid: false, unlocks: [])
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode)
        }
        return try JSONDecoder().decode(RedeemCodeResultDTO.self, from: data)
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

private extension Array {
    /// Splits the array into fixed-size chunks (last chunk may be smaller).
    /// Returns `[]` for an empty array, or the array itself wrapped in a
    /// single chunk when `size <= 0`.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
