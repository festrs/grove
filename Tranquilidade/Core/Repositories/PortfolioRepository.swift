import Foundation
import SwiftData

struct PortfolioSummary {
    let totalValue: Decimal
    let totalValueBRL: Decimal
    let monthlyIncomeGross: Decimal
    let monthlyIncomeNet: Decimal
    let allocationByClass: [AssetClassAllocation]
    let activeCount: Int
    let frozenCount: Int
    let quarantineCount: Int
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
        var active = 0, frozen = 0, quarantine = 0

        for h in holdings {
            let brlValue = h.currency == .usd ? h.currentValue * exchangeRate : h.currentValue
            totalBRL += brlValue
            valueByClass[h.assetClass, default: 0] += brlValue

            let monthlyGross = h.estimatedMonthlyIncome
            let brlMonthly = h.currency == .usd ? monthlyGross * exchangeRate : monthlyGross
            grossByClass[h.assetClass, default: 0] += brlMonthly

            switch h.status {
            case .aportar: active += 1
            case .congelar: frozen += 1
            case .quarentena: quarantine += 1
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
            totalValue: holdings.reduce(Decimal.zero) { $0 + $1.currentValue },
            totalValueBRL: totalBRL,
            monthlyIncomeGross: totalGross,
            monthlyIncomeNet: breakdown.totalNet,
            allocationByClass: allocations,
            activeCount: active,
            frozenCount: frozen,
            quarantineCount: quarantine
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
