import Foundation

extension Decimal {
    func formatted(as currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = currency.locale
        formatter.currencySymbol = currency.symbol
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "\(currency.symbol) 0,00"
    }

    func formattedBRL() -> String {
        formatted(as: .brl)
    }

    func formattedPercent(decimals: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.multiplier = 1 // value is already in percent form (e.g., 27.5 → "27.5%")
        return formatter.string(from: self as NSDecimalNumber) ?? "0%"
    }

    func formattedCompact() -> String {
        let doubleValue = NSDecimalNumber(decimal: self).doubleValue
        if abs(doubleValue) >= 1_000_000 {
            return String(format: "%.1fM", doubleValue / 1_000_000)
        } else if abs(doubleValue) >= 1_000 {
            return String(format: "%.1fk", doubleValue / 1_000)
        }
        return String(format: "%.0f", doubleValue)
    }
}
