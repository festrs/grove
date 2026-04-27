import Foundation
import SwiftData
import GroveDomain
import GroveServices

public struct PortfolioSummary {
    public let totalValue: Money
    public let monthlyIncomeGross: Money
    public let monthlyIncomeNet: Money
    public let allocationByClass: [AssetClassAllocation]
    public let studyCount: Int
    public let activeCount: Int
    public let quarantineCount: Int
    public let sellingCount: Int

    public init(
        totalValue: Money,
        monthlyIncomeGross: Money,
        monthlyIncomeNet: Money,
        allocationByClass: [AssetClassAllocation],
        studyCount: Int,
        activeCount: Int,
        quarantineCount: Int,
        sellingCount: Int
    ) {
        self.totalValue = totalValue
        self.monthlyIncomeGross = monthlyIncomeGross
        self.monthlyIncomeNet = monthlyIncomeNet
        self.allocationByClass = allocationByClass
        self.studyCount = studyCount
        self.activeCount = activeCount
        self.quarantineCount = quarantineCount
        self.sellingCount = sellingCount
    }
}

public struct AssetClassAllocation: Identifiable {
    public var id: String { assetClass.rawValue }
    public let assetClass: AssetClassType
    public let currentValue: Money
    public let currentPercent: Decimal
    public let targetPercent: Decimal
    public let drift: Decimal // current - target (positive = overweight)

    public init(
        assetClass: AssetClassType,
        currentValue: Money,
        currentPercent: Decimal,
        targetPercent: Decimal,
        drift: Decimal
    ) {
        self.assetClass = assetClass
        self.currentValue = currentValue
        self.currentPercent = currentPercent
        self.targetPercent = targetPercent
        self.drift = drift
    }
}

public struct PortfolioRepository {
    public let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchDefaultPortfolio() throws -> Portfolio? {
        var descriptor = FetchDescriptor<Portfolio>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    public func fetchAllPortfolios() throws -> [Portfolio] {
        let descriptor = FetchDescriptor<Portfolio>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetchAllHoldings() throws -> [Holding] {
        let descriptor = FetchDescriptor<Holding>(
            sortBy: [SortDescriptor(\.ticker)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func computeSummary(
        holdings: [Holding],
        classAllocations: [AssetClassType: Double] = [:],
        displayCurrency: Currency,
        rates: any ExchangeRates
    ) -> PortfolioSummary {
        var grossByClass: [AssetClassType: Money] = [:]
        var valueByClass: [AssetClassType: Money] = [:]
        var totalValues: [Money] = []
        var grossValues: [Money] = []
        var study = 0, active = 0, quarantine = 0, selling = 0

        for h in holdings {
            let value = h.currentValueMoney
            totalValues.append(value)
            valueByClass[h.assetClass] = (valueByClass[h.assetClass] ?? .zero(in: h.currency)) + value

            let gross = h.estimatedMonthlyIncomeMoney
            grossValues.append(gross)
            grossByClass[h.assetClass] = (grossByClass[h.assetClass] ?? .zero(in: h.currency)) + gross

            switch h.status {
            case .estudo: study += 1
            case .aportar: active += 1
            case .quarentena: quarantine += 1
            case .vender: selling += 1
            }
        }

        let totalValue = totalValues.sum(in: displayCurrency, using: rates)
        let totalGross = grossValues.sum(in: displayCurrency, using: rates)
        let breakdown = TaxCalculator.taxBreakdown(
            grossByClass: grossByClass,
            displayCurrency: displayCurrency,
            rates: rates
        )

        let allocations = AssetClassType.allCases.compactMap { classType -> AssetClassAllocation? in
            let nativeValue = valueByClass[classType] ?? .zero(in: displayCurrency)
            let displayValue = nativeValue.converted(to: displayCurrency, using: rates)
            let currentPct: Decimal = totalValue.amount > 0 ? (displayValue.amount / totalValue.amount) * 100 : 0
            let targetPct = Decimal(classAllocations[classType] ?? 0)
            guard displayValue.amount > 0 || targetPct > 0 else { return nil }
            return AssetClassAllocation(
                assetClass: classType,
                currentValue: displayValue,
                currentPercent: currentPct,
                targetPercent: targetPct,
                drift: currentPct - targetPct
            )
        }

        return PortfolioSummary(
            totalValue: totalValue,
            monthlyIncomeGross: totalGross,
            monthlyIncomeNet: breakdown.totalNet,
            allocationByClass: allocations,
            studyCount: study,
            activeCount: active,
            quarantineCount: quarantine,
            sellingCount: selling
        )
    }

    /// Persist the result of onboarding: portfolio (auto-renamed if a name
    /// collides), holdings (with bootstrap contributions when the user already
    /// has a position), and user settings (allocations limited to in-use classes
    /// to avoid breaking the 100% sum invariant).
    ///
    /// `nameFallbacks` is a pool of alternative names tried in order when
    /// `preferredName` already exists. The view layer owns the copywriting.
    @discardableResult
    public func saveOnboardingPortfolio(
        preferredName: String,
        nameFallbacks: [String],
        pendingHoldings: [PendingHolding],
        targetAllocations: [AssetClassType: Decimal],
        monthlyIncomeGoal: Decimal,
        monthlyCostOfLiving: Decimal
    ) throws -> Portfolio {
        let existing = (try? modelContext.fetch(FetchDescriptor<Portfolio>())) ?? []
        let existingNames = Set(existing.map(\.name))

        let resolvedName: String
        if existingNames.contains(preferredName) {
            resolvedName = nameFallbacks.first { !existingNames.contains($0) }
                ?? "Portfolio \(existing.count + 1)"
        } else {
            resolvedName = preferredName
        }

        let portfolio = Portfolio(name: resolvedName)
        modelContext.insert(portfolio)

        for pending in pendingHoldings {
            let holding = Holding(
                ticker: pending.ticker,
                displayName: pending.displayName,
                currentPrice: pending.currentPrice,
                dividendYield: pending.dividendYield,
                assetClass: pending.assetClass,
                status: pending.status
            )
            holding.portfolio = portfolio
            modelContext.insert(holding)

            // Bootstrap contribution when the user reports an existing position.
            if pending.quantity > 0 {
                let contribution = Contribution(
                    date: .now,
                    amount: pending.quantity * pending.currentPrice,
                    shares: pending.quantity,
                    pricePerShare: pending.currentPrice
                )
                contribution.holding = holding
                modelContext.insert(contribution)
                holding.recalculateFromContributions()
            }
        }

        // Only persist allocations for classes the user actually has — writing
        // the full dict (with defaults for unused classes) would push the sum
        // past 100 and break the rebalancing invariant.
        let usedClasses = Set(pendingHoldings.map(\.assetClass))
        let allocationsToPersist = Dictionary(uniqueKeysWithValues:
            targetAllocations
                .filter { usedClasses.contains($0.key) }
                .map { ($0.key, NSDecimalNumber(decimal: $0.value).doubleValue) }
        )

        let settings = try fetchSettings()
        settings.monthlyIncomeGoal = monthlyIncomeGoal
        settings.monthlyCostOfLiving = monthlyCostOfLiving
        settings.classAllocations = allocationsToPersist
        settings.hasCompletedOnboarding = true

        try modelContext.save()
        return portfolio
    }

    public func fetchSettings() throws -> UserSettings {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let settings = UserSettings()
        modelContext.insert(settings)
        return settings
    }
}
