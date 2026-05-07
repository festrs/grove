import Foundation

enum HTTPClient: Sendable {

    nonisolated static func fetch<T: Decodable & Sendable>(
        url: URL,
        headers: [String: String] = [:]
    ) async throws(APIError) -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return try await perform(request: request, url: url, method: "GET")
    }

    nonisolated static func post<T: Decodable & Sendable, B: Encodable & Sendable>(
        url: URL,
        body: B,
        headers: [String: String] = [:]
    ) async throws(APIError) -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            record(method: "POST", url: url, started: Date(), status: nil, success: false)
            throw .unknown("Erro ao codificar dados: \(error.localizedDescription)")
        }

        return try await perform(request: request, url: url, method: "POST")
    }

    private nonisolated static func perform<T: Decodable & Sendable>(
        request: URLRequest,
        url: URL,
        method: String
    ) async throws(APIError) -> T {
        let started = Date()
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            record(method: method, url: url, started: started, status: nil, success: false)
            throw .networkError(urlError)
        } catch {
            record(method: method, url: url, started: started, status: nil, success: false)
            throw .unknown(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            record(method: method, url: url, started: started, status: nil, success: false)
            throw .unknown("Resposta invalida do servidor.")
        }

        let status = httpResponse.statusCode
        switch status {
        case 200 ..< 300:
            break
        case 403:
            record(method: method, url: url, started: started, status: status, success: false)
            throw .unauthorized
        case 404:
            record(method: method, url: url, started: started, status: status, success: false)
            throw .notFound
        case 429:
            record(method: method, url: url, started: started, status: status, success: false)
            throw .rateLimited
        default:
            record(method: method, url: url, started: started, status: status, success: false)
            throw .httpError(statusCode: status)
        }

        do {
            let decoder = JSONDecoder()
            let value = try decoder.decode(T.self, from: data)
            record(method: method, url: url, started: started, status: status, success: true)
            return value
        } catch {
            record(method: method, url: url, started: started, status: status, success: false)
            throw .decodingError(error.localizedDescription)
        }
    }

    private nonisolated static func record(
        method: String,
        url: URL,
        started: Date,
        status: Int?,
        success: Bool
    ) {
        let durationMS = Int(Date().timeIntervalSince(started) * 1000)
        let path = url.path
        Task { @MainActor in
            NetworkActivityLog.shared.record(
                method: method,
                path: path,
                status: status,
                durationMS: durationMS,
                success: success
            )
        }
    }
}
