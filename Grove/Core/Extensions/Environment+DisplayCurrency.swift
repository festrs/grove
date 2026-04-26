import SwiftUI

private struct DisplayCurrencyKey: EnvironmentKey {
    static let defaultValue: Currency = .brl
}

private struct ExchangeRatesKey: EnvironmentKey {
    static let defaultValue: any ExchangeRates = IdentityRates()
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
