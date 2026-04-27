import Foundation
import GroveDomain

public struct TaxCalculator {
    /// Returns the net multiplier for a given asset class
    public static func netMultiplier(for assetClass: AssetClassType) -> Decimal {
        assetClass.defaultTaxTreatment.netMultiplier
    }

    /// Calculate net income from gross income for a given asset class
    public static func netIncome(gross: Decimal, assetClass: AssetClassType) -> Decimal {
        gross * netMultiplier(for: assetClass)
    }

    /// Calculate withholding tax amount
    public static func withholdingTax(gross: Decimal, assetClass: AssetClassType) -> Decimal {
        gross * (1 - netMultiplier(for: assetClass))
    }

    /// Decimal-keyed breakdown — tax math is currency-agnostic per class.
    public static func taxBreakdown(grossByClass: [AssetClassType: Decimal]) -> TaxBreakdownResult {
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
    public static func taxBreakdown(
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

public struct TaxBreakdownResult {
    public let totalGross: Decimal
    public let totalTax: Decimal
    public let totalNet: Decimal
    public let details: [TaxBreakdownDetail]

    public init(totalGross: Decimal, totalTax: Decimal, totalNet: Decimal, details: [TaxBreakdownDetail]) {
        self.totalGross = totalGross
        self.totalTax = totalTax
        self.totalNet = totalNet
        self.details = details
    }
}

public struct TaxBreakdownDetail: Identifiable {
    public var id: String { assetClass.rawValue }
    public let assetClass: AssetClassType
    public let gross: Decimal
    public let tax: Decimal
    public let net: Decimal

    public init(assetClass: AssetClassType, gross: Decimal, tax: Decimal, net: Decimal) {
        self.assetClass = assetClass
        self.gross = gross
        self.tax = tax
        self.net = net
    }
}

public struct MoneyTaxBreakdown {
    public let totalGross: Money
    public let totalTax: Money
    public let totalNet: Money
    public let details: [MoneyTaxBreakdownDetail]

    public init(totalGross: Money, totalTax: Money, totalNet: Money, details: [MoneyTaxBreakdownDetail]) {
        self.totalGross = totalGross
        self.totalTax = totalTax
        self.totalNet = totalNet
        self.details = details
    }
}

public struct MoneyTaxBreakdownDetail: Identifiable {
    public var id: String { assetClass.rawValue }
    public let assetClass: AssetClassType
    public let gross: Money
    public let tax: Money
    public let net: Money

    public init(assetClass: AssetClassType, gross: Money, tax: Money, net: Money) {
        self.assetClass = assetClass
        self.gross = gross
        self.tax = tax
        self.net = net
    }
}
