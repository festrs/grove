import SwiftUI

private struct DisplayCurrencyKey: EnvironmentKey {
    static let defaultValue: Currency = .brl
}

extension EnvironmentValues {
    /// Currency the user wants portfolio totals expressed in.
    /// Read in shared views via `@Environment(\.displayCurrency)`.
    var displayCurrency: Currency {
        get { self[DisplayCurrencyKey.self] }
        set { self[DisplayCurrencyKey.self] = newValue }
    }
}
