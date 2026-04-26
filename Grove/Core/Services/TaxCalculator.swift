import Foundation

struct TaxCalculator {
    /// Returns the net multiplier for a given asset class
    static func netMultiplier(for assetClass: AssetClassType) -> Decimal {
        assetClass.defaultTaxTreatment.netMultiplier
    }

    /// Calculate net income from gross income for a given asset class
    static func netIncome(gross: Decimal, assetClass: AssetClassType) -> Decimal {
        gross * netMultiplier(for: assetClass)
    }

    /// Calculate withholding tax amount
    static func withholdingTax(gross: Decimal, assetClass: AssetClassType) -> Decimal {
        gross * (1 - netMultiplier(for: assetClass))
    }

    /// Decimal-keyed breakdown — tax math is currency-agnostic per class.
    static func taxBreakdown(grossByClass: [AssetClassType: Decimal]) -> TaxBreakdownResult {
        var totalGross: Decimal = 0
        var totalTax: Decimal = 0
        var details: [TaxBreakdownDetail] = []

        for (assetClass, gross) in grossByClass.sorted(by: { $0.value > $1.value }) {
            let tax = withholdingTax(gross: gross, assetClass: assetClass)
            let net = gross - tax
            totalGross += gross
            totalTax += tax
            details.append(TaxBreakdownDetail(
                assetClass: assetClass,
                gross: gross,
                tax: tax,
                net: net
            ))
        }

        return TaxBreakdownResult(
            totalGross: totalGross,
            totalTax: totalTax,
            totalNet: totalGross - totalTax,
            details: details
        )
    }

    /// Money-aware breakdown — each class is taxed in its own currency, then summed
    /// in the display currency via FX. Returned details remain native per class.
    static func taxBreakdown(
        grossByClass: [AssetClassType: Money],
        displayCurrency: Currency,
        rates: any ExchangeRates
    ) -> MoneyTaxBreakdown {
        var grossValues: [Money] = []
        var taxValues: [Money] = []
        var netValues: [Money] = []
        var details: [MoneyTaxBreakdownDetail] = []

        for (assetClass, gross) in grossByClass.sorted(by: { $0.value.amount > $1.value.amount }) {
            let multiplier = netMultiplier(for: assetClass)
            let net = Money(amount: gross.amount * multiplier, currency: gross.currency)
            let tax = Money(amount: gross.amount * (1 - multiplier), currency: gross.currency)
            grossValues.append(gross)
            taxValues.append(tax)
            netValues.append(net)
            details.append(MoneyTaxBreakdownDetail(
                assetClass: assetClass,
                gross: gross,
                tax: tax,
                net: net
            ))
        }

        return MoneyTaxBreakdown(
            totalGross: grossValues.sum(in: displayCurrency, using: rates),
            totalTax: taxValues.sum(in: displayCurrency, using: rates),
            totalNet: netValues.sum(in: displayCurrency, using: rates),
            details: details
        )
    }
}

struct TaxBreakdownResult {
    let totalGross: Decimal
    let totalTax: Decimal
    let totalNet: Decimal
    let details: [TaxBreakdownDetail]
}

struct TaxBreakdownDetail: Identifiable {
    var id: String { assetClass.rawValue }
    let assetClass: AssetClassType
    let gross: Decimal
    let tax: Decimal
    let net: Decimal
}

struct MoneyTaxBreakdown {
    let totalGross: Money
    let totalTax: Money
    let totalNet: Money
    let details: [MoneyTaxBreakdownDetail]
}

struct MoneyTaxBreakdownDetail: Identifiable {
    var id: String { assetClass.rawValue }
    let assetClass: AssetClassType
    let gross: Money
    let tax: Money
    let net: Money
}
