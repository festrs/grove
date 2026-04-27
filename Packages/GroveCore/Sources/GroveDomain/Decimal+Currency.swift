import Foundation

/// Cached `NumberFormatter` instances. Allocating a formatter per call is
/// expensive (Foundation walks ICU tables), so keep one per (currency, style).
/// Access is single-threaded — these helpers run on the main actor (UI) and
/// from synchronous formatting paths; do NOT mutate from background tasks.
@MainActor
public enum Formatters {
    private static var currencyByRaw: [String: NumberFormatter] = [:]
    private static var decimalByRaw: [String: NumberFormatter] = [:]
    private static var percentByDecimals: [Int: NumberFormatter] = [:]

    public static func currency(_ currency: Currency) -> NumberFormatter {
        if let cached = currencyByRaw[currency.rawValue] { return cached }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = currency.locale
        f.currencySymbol = currency.symbol
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        currencyByRaw[currency.rawValue] = f
        return f
    }

    public static func decimal(_ currency: Currency) -> NumberFormatter {
        if let cached = decimalByRaw[currency.rawValue] { return cached }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = currency.locale
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        decimalByRaw[currency.rawValue] = f
        return f
    }

    public static func percent(decimals: Int) -> NumberFormatter {
        if let cached = percentByDecimals[decimals] { return cached }
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        f.multiplier = 1 // value is already in percent form (e.g., 27.5 → "27.5%")
        percentByDecimals[decimals] = f
        return f
    }
}

extension Decimal {
    public func formatted(as currency: Currency) -> String {
        let formatter = MainActor.assumeIsolated { Formatters.currency(currency) }
        return formatter.string(from: self as NSDecimalNumber) ?? "\(currency.symbol) 0,00"
    }

    public func formattedPercent(decimals: Int = 1) -> String {
        let formatter = MainActor.assumeIsolated { Formatters.percent(decimals: decimals) }
        return formatter.string(from: self as NSDecimalNumber) ?? "0%"
    }

    public func formattedCompact() -> String {
        let doubleValue = NSDecimalNumber(decimal: self).doubleValue
        if abs(doubleValue) >= 1_000_000 {
            return String(format: "%.1fM", doubleValue / 1_000_000)
        } else if abs(doubleValue) >= 1_000 {
            return String(format: "%.1fk", doubleValue / 1_000)
        }
        return String(format: "%.0f", doubleValue)
    }
}
