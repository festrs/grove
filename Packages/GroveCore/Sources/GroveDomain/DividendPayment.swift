import Foundation
import SwiftData

@Model
public final class DividendPayment {
    public var exDate: Date
    public var paymentDate: Date
    public var amountPerShare: Decimal
    public var taxTreatmentRaw: String

    public var holding: Holding?

    public var taxTreatment: TaxTreatment {
        get { TaxTreatment(rawValue: taxTreatmentRaw) ?? .exempt }
        set { taxTreatmentRaw = newValue.rawValue }
    }

    /// Live earnings derived from the holding's current share count.
    /// Recomputes automatically as buys/sells change `holding.quantity`.
    public var totalAmount: Decimal {
        amountPerShare * (holding?.quantity ?? 0)
    }

    public var withholdingTax: Decimal {
        totalAmount * (1 - taxTreatment.netMultiplier)
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

    /// True when the linked holding has no shares (typically `.estudo`),
    /// so the row should display the per-share amount instead of earnings.
    public var isInformational: Bool {
        (holding?.quantity ?? 0) == 0
    }

    public init(
        exDate: Date,
        paymentDate: Date,
        amountPerShare: Decimal,
        taxTreatment: TaxTreatment = .exempt
    ) {
        self.exDate = exDate
        self.paymentDate = paymentDate
        self.amountPerShare = amountPerShare
        self.taxTreatmentRaw = taxTreatment.rawValue
    }
}
