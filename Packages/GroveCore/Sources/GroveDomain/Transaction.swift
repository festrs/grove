import Foundation
import SwiftData

@Model
public final class Transaction {
    public var date: Date
    public var amount: Decimal
    public var shares: Decimal
    public var pricePerShare: Decimal

    public var holding: Holding?

    public var pricePerShareMoney: Money {
        Money(amount: pricePerShare, currency: holding?.currency ?? .brl)
    }

    /// Negative-share transactions are the closing entries written by
    /// the sell + remove flows. Used by UIs to pick a label/color without
    /// re-deriving the sign rule at every call site.
    public var isBuy: Bool { shares > 0 }

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
