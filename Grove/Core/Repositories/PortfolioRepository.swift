import Foundation
import SwiftData

struct PortfolioSummary {
    let totalValue: Money
    let monthlyIncomeGross: Money
    let monthlyIncomeNet: Money
    let allocationByClass: [AssetClassAllocation]
    let studyCount: Int
    let activeCount: Int
    let quarantineCount: Int
    let sellingCount: Int
}

struct AssetClassAllocation: Identifiable {
    var id: String { assetClass.rawValue }
    let assetClass: AssetClassType
    let currentValue: Money
    let currentPercent: Decimal
    let targetPercent: Decimal
    let drift: Decimal // current - target (positive = overweight)
}

struct PortfolioRepository {
    let modelContext: ModelContext

    func fetchDefaultPortfolio() throws -> Portfolio? {
        var descriptor = FetchDescriptor<Portfolio>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func fetchAllPortfolios() throws -> [Portfolio] {
        let descriptor = FetchDescriptor<Portfolio>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchAllHoldings() throws -> [Holding] {
        let descriptor = FetchDescriptor<Holding>(
            sortBy: [SortDescriptor(\.ticker)]
        )
        return try modelContext.fetch(descriptor)
    }

    func computeSummary(
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

    func fetchSettings() throws -> UserSettings {
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
