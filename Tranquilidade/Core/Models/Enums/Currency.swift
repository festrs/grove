import Foundation

enum Currency: String, Codable, CaseIterable, Identifiable {
    case brl
    case usd

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .brl: "R$"
        case .usd: "$"
        }
    }

    var code: String {
        switch self {
        case .brl: "BRL"
        case .usd: "USD"
        }
    }

    var locale: Locale {
        switch self {
        case .brl: Locale(identifier: "pt_BR")
        case .usd: Locale(identifier: "en_US")
        }
    }
}
