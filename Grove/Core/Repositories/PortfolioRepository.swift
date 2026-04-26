import Foundation
import SwiftData

struct PortfolioSummary {
    /// Total portfolio value expressed in the user's display currency
    /// (currently BRL — non-BRL holdings are converted via the exchange rate).
    let totalValue: Decimal
    let monthlyIncomeGross: Decimal
    let monthlyIncomeNet: Decimal
    let allocationByClass: [AssetClassAllocation]
    let studyCount: Int
    let activeCount: Int
    let quarantineCount: Int
    let sellingCount: Int
}

struct AssetClassAllocation: Identifiable {
    var id: String { assetClass.rawValue }
    let assetClass: AssetClassType
    let currentValue: Decimal
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

    func computeSummary(holdings: [Holding], classAllocations: [AssetClassType: Double] = [:], exchangeRate: Decimal = 5.12) -> PortfolioSummary {
        var totalBRL: Decimal = 0
        var grossByClass: [AssetClassType: Decimal] = [:]
        var valueByClass: [AssetClassType: Decimal] = [:]
        var study = 0, active = 0, quarantine = 0, selling = 0

        for h in holdings {
            let brlValue = h.currency == .usd ? h.currentValue * exchangeRate : h.currentValue
            totalBRL += brlValue
            valueByClass[h.assetClass, default: 0] += brlValue

            let monthlyGross = h.estimatedMonthlyIncome
            let brlMonthly = h.currency == .usd ? monthlyGross * exchangeRate : monthlyGross
            grossByClass[h.assetClass, default: 0] += brlMonthly

            switch h.status {
            case .estudo: study += 1
            case .aportar: active += 1
            case .quarentena: quarantine += 1
            case .vender: selling += 1
            }
        }

        let totalGross = grossByClass.values.reduce(Decimal.zero, +)
        let breakdown = TaxCalculator.taxBreakdown(grossByClass: grossByClass)

        // Use portfolio class allocations as target (source of truth)
        let allocations = AssetClassType.allCases.compactMap { classType -> AssetClassAllocation? in
            let value = valueByClass[classType] ?? 0
            let currentPct = totalBRL > 0 ? (value / totalBRL) * 100 : 0
            let targetPct = Decimal(classAllocations[classType] ?? 0)
            guard value > 0 || targetPct > 0 else { return nil }
            return AssetClassAllocation(
                assetClass: classType,
                currentValue: value,
                currentPercent: currentPct,
                targetPercent: targetPct,
                drift: currentPct - targetPct
            )
        }

        return PortfolioSummary(
            totalValue: totalBRL,
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
