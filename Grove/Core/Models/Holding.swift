import Foundation
import SwiftData
import SwiftUI

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

    // Optional enrichment data
    var sector: String?
    var logoURL: String?
    var marketCap: String?

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
        get {
            if statusRaw == "congelar" { return .quarentena }
            return HoldingStatus(rawValue: statusRaw) ?? .aportar
        }
        set { statusRaw = newValue.rawValue }
    }

    var hasPosition: Bool {
        quantity > 0
    }

    var hasCompanyInfo: Bool {
        sector != nil || marketCap != nil || logoURL != nil
    }

    var currentValue: Decimal {
        quantity * currentPrice
    }

    var totalCost: Decimal {
        quantity * averagePrice
    }

    var priceMoney: Money {
        Money(amount: currentPrice, currency: currency)
    }

    var averagePriceMoney: Money {
        Money(amount: averagePrice, currency: currency)
    }

    var currentValueMoney: Money {
        Money(amount: currentPrice * quantity, currency: currency)
    }

    var estimatedMonthlyIncomeMoney: Money {
        Money(amount: estimatedMonthlyIncome, currency: currency)
    }

    var estimatedMonthlyIncomeNetMoney: Money {
        Money(amount: estimatedMonthlyIncomeNet, currency: currency)
    }

    var gainLoss: Decimal {
        currentValue - totalCost
    }

    var gainLossPercent: Decimal {
        guard totalCost > 0 else { return 0 }
        return (gainLoss / totalCost) * 100
    }

    var gainLossColor: Color {
        gainLossPercent >= 0 ? .tqPositive : .tqNegative
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

    // MARK: - Free Tier Limit

    static func canAddMore(modelContext: ModelContext) -> Bool {
        let count = (try? modelContext.fetchCount(FetchDescriptor<Holding>())) ?? 0
        return count < AppConstants.freeTierMaxHoldings
    }

    static func remainingSlots(modelContext: ModelContext) -> Int {
        let count = (try? modelContext.fetchCount(FetchDescriptor<Holding>())) ?? 0
        return max(AppConstants.freeTierMaxHoldings - count, 0)
    }

    static let freeTierLimitMessage = "Limit of \(AppConstants.freeTierMaxHoldings) assets on the free plan."

    // MARK: - Contribution-Based Recalculation

    /// Recomputes quantity and averagePrice from the contributions ledger.
    /// Call this after inserting a new Contribution.
    func recalculateFromContributions() {
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
