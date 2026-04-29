import SwiftUI
import GroveDomain

private struct DisplayCurrencyKey: EnvironmentKey {
    static let defaultValue: Currency = .brl
}

private struct ExchangeRatesKey: EnvironmentKey {
    /// Fallback for views that read `\.rates` before a real rate provider is
    /// injected. Uses a recent USD/BRL approximation so cross-currency math
    /// produces stale-but-reasonable numbers instead of crashing.
    static let defaultValue: any ExchangeRates = StaticRates(brlPerUsd: 5.15)
}

extension EnvironmentValues {
    /// Currency the user wants portfolio totals expressed in.
    /// Read in shared views via `@Environment(\.displayCurrency)`.
    var displayCurrency: Currency {
        get { self[DisplayCurrencyKey.self] }
        set { self[DisplayCurrencyKey.self] = newValue }
    }

    /// Live FX rate provider. Read via `@Environment(\.rates)`.
    var rates: any ExchangeRates {
        get { self[ExchangeRatesKey.self] }
        set { self[ExchangeRatesKey.self] = newValue }
    }
}
