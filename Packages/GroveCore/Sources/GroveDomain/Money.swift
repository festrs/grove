import Foundation

public struct Money: Equatable, Hashable, Sendable {
    public let amount: Decimal
    public let currency: Currency

    public static func zero(in currency: Currency) -> Money {
        Money(amount: 0, currency: currency)
    }

    public static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Cannot add Money with different currencies (\(lhs.currency.rawValue) vs \(rhs.currency.rawValue))")
        return Money(amount: lhs.amount + rhs.amount, currency: lhs.currency)
    }

    public static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Cannot subtract Money with different currencies (\(lhs.currency.rawValue) vs \(rhs.currency.rawValue))")
        return Money(amount: lhs.amount - rhs.amount, currency: lhs.currency)
    }

    public static func * (lhs: Money, rhs: Decimal) -> Money {
        Money(amount: lhs.amount * rhs, currency: lhs.currency)
    }

    public static func * (lhs: Decimal, rhs: Money) -> Money {
        Money(amount: lhs * rhs.amount, currency: rhs.currency)
    }

    public static func / (lhs: Money, rhs: Decimal) -> Money {
        Money(amount: lhs.amount / rhs, currency: lhs.currency)
    }

    public static prefix func - (operand: Money) -> Money {
        Money(amount: -operand.amount, currency: operand.currency)
    }

    public func converted(to target: Currency, using rates: any ExchangeRates) -> Money {
        if currency == target { return self }
        let factor = rates.rate(from: currency, to: target)
        return Money(amount: amount * factor, currency: target)
    }

    public func formatted() -> String {
        amount.formatted(as: currency)
    }

    public func formatted(in target: Currency, using rates: any ExchangeRates) -> String {
        converted(to: target, using: rates).formatted()
    }

    /// Compact, glanceable currency string for tight UI (gauges, KPI tiles).
    /// Uses the target currency's locale for the decimal separator and one
    /// fractional digit at most: `R$ 4,9k`, `R$ 1,2M`, `$ 750k`. Below 1k the
    /// full precision form is returned so small values keep their cents.
    public func formattedCompact(in target: Currency, using rates: any ExchangeRates) -> String {
        let value = converted(to: target, using: rates)
        let magnitude = abs(NSDecimalNumber(decimal: value.amount).doubleValue)
        let (scaled, suffix): (Double, String)
        switch magnitude {
        case 1_000_000...:
            scaled = NSDecimalNumber(decimal: value.amount).doubleValue / 1_000_000
            suffix = "M"
        case 1_000...:
            scaled = NSDecimalNumber(decimal: value.amount).doubleValue / 1_000
            suffix = "k"
        default:
            return value.formatted()
        }
        let formatter = NumberFormatter()
        formatter.locale = target.locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = scaled.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        let number = formatter.string(from: NSNumber(value: scaled)) ?? "0"
        return "\(target.symbol) \(number)\(suffix)"
    }

    public init(amount: Decimal, currency: Currency) {
        self.amount = amount
        self.currency = currency
    }

    public init?(dto: MoneyDTO) {
        guard let parsedAmount = Decimal(string: dto.amount),
              let parsedCurrency = Currency(rawValue: dto.currency.lowercased()) else {
            return nil
        }
        self.amount = parsedAmount
        self.currency = parsedCurrency
    }

    public var dto: MoneyDTO {
        MoneyDTO(amount: NSDecimalNumber(decimal: amount).stringValue, currency: currency.rawValue.uppercased())
    }
}

extension Money: Comparable {
    public static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency, "Cannot compare Money with different currencies (\(lhs.currency.rawValue) vs \(rhs.currency.rawValue))")
        return lhs.amount < rhs.amount
    }
}

extension Sequence where Element == Money {
    public func sum(in target: Currency, using rates: any ExchangeRates) -> Money {
        reduce(Money.zero(in: target)) { acc, money in
            acc + money.converted(to: target, using: rates)
        }
    }
}
