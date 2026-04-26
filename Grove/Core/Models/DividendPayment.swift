import Foundation
import SwiftData

@Model
final class DividendPayment {
    var exDate: Date
    var paymentDate: Date
    var amountPerShare: Decimal
    var totalAmount: Decimal
    var taxTreatmentRaw: String
    var withholdingTax: Decimal

    var holding: Holding?

    var taxTreatment: TaxTreatment {
        get { TaxTreatment(rawValue: taxTreatmentRaw) ?? .exempt }
        set { taxTreatmentRaw = newValue.rawValue }
    }

    var netAmount: Decimal {
        totalAmount - withholdingTax
    }

    private var resolvedCurrency: Currency {
        holding?.currency ?? .brl
    }

    var amountPerShareMoney: Money {
        Money(amount: amountPerShare, currency: resolvedCurrency)
    }

    var totalAmountMoney: Money {
        Money(amount: totalAmount, currency: resolvedCurrency)
    }

    var netAmountMoney: Money {
        Money(amount: netAmount, currency: resolvedCurrency)
    }

    var withholdingTaxMoney: Money {
        Money(amount: withholdingTax, currency: resolvedCurrency)
    }

    /// True when the payment is informational only — the holding has no shares
    /// (typically status `.estudo`), so we show the per-share amount instead
    /// of an earnings figure.
    var isInformational: Bool {
        totalAmount == 0
    }

    init(
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
