import Foundation

protocol ExchangeRates: Sendable {
    func rate(from source: Currency, to target: Currency) -> Decimal
}

struct IdentityRates: ExchangeRates {
    func rate(from source: Currency, to target: Currency) -> Decimal {
        if source == target { return 1 }
        fatalError("IdentityRates cannot convert \(source.rawValue) → \(target.rawValue) — inject a real ExchangeRates implementation.")
    }
}

struct StaticRates: ExchangeRates {
    let brlPerUsd: Decimal

    func rate(from source: Currency, to target: Currency) -> Decimal {
        if source == target { return 1 }
        switch (source, target) {
        case (.usd, .brl): return brlPerUsd
        case (.brl, .usd): return 1 / brlPerUsd
        default: return 1
        }
    }
}
