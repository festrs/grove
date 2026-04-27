import Foundation
import SwiftData

@Model
public final class Holding {
    public var ticker: String
    public var displayName: String
    public var quantity: Decimal
    public var averagePrice: Decimal
    public var currentPrice: Decimal
    public var dividendYield: Decimal

    // Stored as raw strings for SwiftData compatibility
    public var assetClassRaw: String
    public var currencyRaw: String
    public var statusRaw: String

    public var targetPercent: Decimal
    public var lastPriceUpdate: Date?

    // Optional enrichment data
    public var sector: String?
    public var logoURL: String?
    public var marketCap: String?

    public var portfolio: Portfolio?

    @Relationship(deleteRule: .cascade, inverse: \DividendPayment.holding)
    public var dividends: [DividendPayment]

    @Relationship(deleteRule: .cascade, inverse: \Contribution.holding)
    public var contributions: [Contribution]

    // MARK: - Computed Properties

    public var displayTicker: String {
        ticker.replacingOccurrences(of: ".SA", with: "")
    }

    public var assetClass: AssetClassType {
        get { AssetClassType(rawValue: assetClassRaw) ?? .acoesBR }
        set { assetClassRaw = newValue.rawValue }
    }

    public var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .brl }
        set { currencyRaw = newValue.rawValue }
    }

    public var status: HoldingStatus {
        get {
            if statusRaw == "congelar" { return .quarentena }
            return HoldingStatus(rawValue: statusRaw) ?? .aportar
        }
        set { statusRaw = newValue.rawValue }
    }

    public var hasPosition: Bool {
        quantity > 0
    }

    public var hasCompanyInfo: Bool {
        sector != nil || marketCap != nil || logoURL != nil
    }

    public var currentValue: Decimal {
        quantity * currentPrice
    }

    public var totalCost: Decimal {
        quantity * averagePrice
    }

    public var priceMoney: Money {
        Money(amount: currentPrice, currency: currency)
    }

    public var averagePriceMoney: Money {
        Money(amount: averagePrice, currency: currency)
    }

    public var currentValueMoney: Money {
        Money(amount: currentPrice * quantity, currency: currency)
    }

    public var estimatedMonthlyIncomeMoney: Money {
        Money(amount: estimatedMonthlyIncome, currency: currency)
    }

    public var estimatedMonthlyIncomeNetMoney: Money {
        Money(amount: estimatedMonthlyIncomeNet, currency: currency)
    }

    public var gainLoss: Decimal {
        currentValue - totalCost
    }

    public var gainLossPercent: Decimal {
        guard totalCost > 0 else { return 0 }
        return (gainLoss / totalCost) * 100
    }

    /// Estimated monthly dividend income (gross)
    public var estimatedMonthlyIncome: Decimal {
        guard dividendYield > 0 else { return 0 }
        return (currentValue * dividendYield / 100) / 12
    }

    /// Estimated monthly dividend income (net of taxes)
    public var estimatedMonthlyIncomeNet: Decimal {
        estimatedMonthlyIncome * assetClass.defaultTaxTreatment.netMultiplier
    }

    public init(
        ticker: String,
        displayName: String = "",
        quantity: Decimal = 0,
        averagePrice: Decimal = 0,
        currentPrice: Decimal = 0,
        dividendYield: Decimal = 0,
        assetClass: AssetClassType,
        currency: Currency? = nil,
        status: HoldingStatus = .estudo,
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

    // MARK: - Contribution-Based Recalculation

    /// Recomputes quantity and averagePrice from the contributions ledger.
    /// Call this after inserting a new Contribution.
    public func recalculateFromContributions() {
        var totalShares: Decimal = 0
        var totalCost: Decimal = 0

        for c in contributions.sorted(by: { $0.date < $1.date }) {
            if c.shares > 0 {
                // Buy: add to cost basis
                totalCost += c.shares * c.pricePerShare
                totalShares += c.shares
            } else {
                // Sell: reduce shares, keep average price (cost basis reduces proportionally)
                let sellShares = abs(c.shares)
                if totalShares > 0 {
                    let avgAtSale = totalCost / totalShares
                    totalCost -= sellShares * avgAtSale
                }
                totalShares -= sellShares
            }
        }

        quantity = max(totalShares, 0)
        averagePrice = quantity > 0 ? totalCost / quantity : 0
    }
}
