import Foundation

public enum Currency: String, Codable, CaseIterable, Identifiable, Sendable {
    case brl
    case usd

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .brl: "R$"
        case .usd: "$"
        }
    }

    public var code: String {
        switch self {
        case .brl: "BRL"
        case .usd: "USD"
        }
    }

    public var locale: Locale {
        switch self {
        case .brl: Locale(identifier: "pt_BR")
        case .usd: Locale(identifier: "en_US")
        }
    }

    public var displayName: String {
        switch self {
        case .brl: "Real (R$)"
        case .usd: "US Dollar ($)"
        }
    }
}
