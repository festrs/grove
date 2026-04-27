import Foundation
import SwiftData

@Model
public final class Contribution {
    public var date: Date
    public var amount: Decimal
    public var shares: Decimal
    public var pricePerShare: Decimal

    public var holding: Holding?

    public var pricePerShareMoney: Money {
        Money(amount: pricePerShare, currency: holding?.currency ?? .brl)
    }

    public init(
        date: Date = .now,
        amount: Decimal,
        shares: Decimal,
        pricePerShare: Decimal
    ) {
        self.date = date
        self.amount = amount
        self.shares = shares
        self.pricePerShare = pricePerShare
    }
}
