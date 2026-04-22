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

    /// Summary of tax impact per asset class
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
