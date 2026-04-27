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
