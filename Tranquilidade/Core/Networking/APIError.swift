import Foundation

enum APIError: LocalizedError, Sendable {
    case networkError(URLError)
    case decodingError(String)
    case httpError(statusCode: Int)
    case unauthorized
    case rateLimited
    case notFound
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let error): "Erro de conexao: \(error.localizedDescription)"
        case .decodingError(let msg): "Erro ao processar dados: \(msg)"
        case .httpError(let code): "Erro do servidor: \(code)"
        case .unauthorized: "Acesso nao autorizado."
        case .rateLimited: "Muitas requisicoes. Tente novamente em alguns minutos."
        case .notFound: "Dados nao encontrados."
        case .unknown(let msg): "Erro: \(msg)"
        }
    }
}
