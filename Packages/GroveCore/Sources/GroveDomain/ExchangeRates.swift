import Foundation

public protocol ExchangeRates: Sendable {
    func rate(from source: Currency, to target: Currency) -> Decimal
}

public struct IdentityRates: ExchangeRates {
    public init() {}

    public func rate(from source: Currency, to target: Currency) -> Decimal {
        if source == target { return 1 }
        fatalError("IdentityRates cannot convert \(source.rawValue) → \(target.rawValue) — inject a real ExchangeRates implementation.")
    }
}

public struct StaticRates: ExchangeRates {
    public let brlPerUsd: Decimal

    public init(brlPerUsd: Decimal) {
        self.brlPerUsd = brlPerUsd
    }

    public func rate(from source: Currency, to target: Currency) -> Decimal {
        if source == target { return 1 }
        switch (source, target) {
        case (.usd, .brl): return brlPerUsd
        case (.brl, .usd): return 1 / brlPerUsd
        default: return 1
        }
    }
}
