import Foundation
import SwiftData

@Model
final class Holding {
    var ticker: String
    var displayName: String
    var quantity: Decimal
    var averagePrice: Decimal
    var currentPrice: Decimal
    var dividendYield: Decimal

    // Stored as raw strings for SwiftData compatibility
    var assetClassRaw: String
    var currencyRaw: String
    var statusRaw: String

    var targetPercent: Decimal
    var lastPriceUpdate: Date?

    var portfolio: Portfolio?

    @Relationship(deleteRule: .cascade, inverse: \DividendPayment.holding)
    var dividends: [DividendPayment]

    @Relationship(deleteRule: .cascade, inverse: \Contribution.holding)
    var contributions: [Contribution]

    // MARK: - Computed Properties

    var displayTicker: String {
        ticker.replacingOccurrences(of: ".SA", with: "")
    }

    var assetClass: AssetClassType {
        get { AssetClassType(rawValue: assetClassRaw) ?? .acoesBR }
        set { assetClassRaw = newValue.rawValue }
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .brl }
        set { currencyRaw = newValue.rawValue }
    }

    var status: HoldingStatus {
        get { HoldingStatus(rawValue: statusRaw) ?? .aportar }
        set { statusRaw = newValue.rawValue }
    }

    var currentValue: Decimal {
        quantity * currentPrice
    }

    var totalCost: Decimal {
        quantity * averagePrice
    }

    var gainLoss: Decimal {
        currentValue - totalCost
    }

    var gainLossPercent: Decimal {
        guard totalCost > 0 else { return 0 }
        return (gainLoss / totalCost) * 100
    }

    /// Estimated monthly dividend income (gross)
    var estimatedMonthlyIncome: Decimal {
        guard dividendYield > 0 else { return 0 }
        return (currentValue * dividendYield / 100) / 12
    }

    /// Estimated monthly dividend income (net of taxes)
    var estimatedMonthlyIncomeNet: Decimal {
        estimatedMonthlyIncome * assetClass.defaultTaxTreatment.netMultiplier
    }

    init(
        ticker: String,
        displayName: String = "",
        quantity: Decimal,
        averagePrice: Decimal = 0,
        currentPrice: Decimal = 0,
        dividendYield: Decimal = 0,
        assetClass: AssetClassType,
        currency: Currency? = nil,
        status: HoldingStatus = .aportar,
        targetPercent: Decimal = 5
    ) {
        self.ticker = ticker
        self.displayName = displayName.isEmpty ? ticker : displayName
        self.quantity = quantity
        self.averagePrice = averagePrice
        self.currentPrice = currentPrice
        self.dividendYield = dividendYield
        self.assetClassRaw = assetClass.rawValue
        self.currencyRaw = (currency ?? assetClass.defaultCurrency).rawValue
        self.statusRaw = status.rawValue
        self.targetPercent = targetPercent
        self.dividends = []
        self.contributions = []
    }
}
