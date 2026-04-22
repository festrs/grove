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
