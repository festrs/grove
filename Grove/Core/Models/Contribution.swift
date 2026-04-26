import Foundation
import SwiftData

@Model
final class Contribution {
    var date: Date
    var amount: Decimal
    var shares: Decimal
    var pricePerShare: Decimal

    var holding: Holding?

    var pricePerShareMoney: Money {
        Money(amount: pricePerShare, currency: holding?.currency ?? .brl)
    }

    init(
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
