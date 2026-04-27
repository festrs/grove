import Foundation
import SwiftData

@Model
public final class DividendPayment {
    public var exDate: Date
    public var paymentDate: Date
    public var amountPerShare: Decimal
    public var totalAmount: Decimal
    public var taxTreatmentRaw: String
    public var withholdingTax: Decimal

    public var holding: Holding?

    public var taxTreatment: TaxTreatment {
        get { TaxTreatment(rawValue: taxTreatmentRaw) ?? .exempt }
        set { taxTreatmentRaw = newValue.rawValue }
    }

    public var netAmount: Decimal {
        totalAmount - withholdingTax
    }

    private var resolvedCurrency: Currency {
        holding?.currency ?? .brl
    }

    public var amountPerShareMoney: Money {
        Money(amount: amountPerShare, currency: resolvedCurrency)
    }

    public var totalAmountMoney: Money {
        Money(amount: totalAmount, currency: resolvedCurrency)
    }

    public var netAmountMoney: Money {
        Money(amount: netAmount, currency: resolvedCurrency)
    }

    public var withholdingTaxMoney: Money {
        Money(amount: withholdingTax, currency: resolvedCurrency)
    }

    /// True when the payment is informational only — the holding has no shares
    /// (typically status `.estudo`), so we show the per-share amount instead
    /// of an earnings figure.
    public var isInformational: Bool {
        totalAmount == 0
    }

    public init(
        exDate: Date,
        paymentDate: Date,
        amountPerShare: Decimal,
        quantity: Decimal,
        taxTreatment: TaxTreatment = .exempt
    ) {
        self.exDate = exDate
        self.paymentDate = paymentDate
        self.amountPerShare = amountPerShare
        self.totalAmount = amountPerShare * quantity
        self.taxTreatmentRaw = taxTreatment.rawValue
        self.withholdingTax = (amountPerShare * quantity) * (1 - taxTreatment.netMultiplier)
    }
}
