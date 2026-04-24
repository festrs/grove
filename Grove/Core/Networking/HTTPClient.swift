import Foundation

enum HTTPClient: Sendable {

    nonisolated static func fetch<T: Decodable & Sendable>(
        url: URL,
        headers: [String: String] = [:]
    ) async throws(APIError) -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            throw .networkError(urlError)
        } catch {
            throw .unknown(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw .unknown("Resposta invalida do servidor.")
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            break
        case 403:
            throw .unauthorized
        case 404:
            throw .notFound
        case 429:
            throw .rateLimited
        default:
            throw .httpError(statusCode: httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw .decodingError(error.localizedDescription)
        }
    }

    nonisolated static func post<T: Decodable & Sendable, B: Encodable & Sendable>(
        url: URL,
        body: B,
        headers: [String: String] = [:]
    ) async throws(APIError) -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw .unknown("Erro ao codificar dados: \(error.localizedDescription)")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            throw .networkError(urlError)
        } catch {
            throw .unknown(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw .unknown("Resposta invalida do servidor.")
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            break
        case 403:
            throw .unauthorized
        case 404:
            throw .notFound
        case 429:
            throw .rateLimited
        default:
            throw .httpError(statusCode: httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw .decodingError(error.localizedDescription)
        }
    }
}
