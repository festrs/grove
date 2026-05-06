import Foundation
import SwiftData
import GroveDomain
import GroveServices
import GroveRepositories

// App-only glue: wraps the pure RebalancingEngine.calculate(...) with SwiftData
// fetching so call sites can pass just a ModelContext.
extension RebalancingEngine {
    static func diagnoseEmpty(modelContext: ModelContext) -> RebalancingEmptyReason {
        let repo = PortfolioRepository(modelContext: modelContext)
        let holdingRepo = HoldingRepository(modelContext: modelContext)
        guard let settings = try? repo.fetchSettings() else { return .unknown }
        guard let holdings = try? holdingRepo.fetchAll() else { return .unknown }
        return diagnoseEmpty(holdings: holdings, classAllocations: settings.classAllocations)
    }

    static func suggestions(
        modelContext: ModelContext,
        investmentAmount: Money,
        rates: any ExchangeRates
    ) throws -> [RebalancingSuggestion] {
        let repo = PortfolioRepository(modelContext: modelContext)
        let holdings = try HoldingRepository(modelContext: modelContext).fetchAll()
        let settings = try repo.fetchSettings()

        let globalAllocations = settings.classAllocations

        let raw: [RebalancingSuggestion]
        if globalAllocations.isEmpty {
            raw = calculate(
                holdings: holdings,
                investmentAmount: investmentAmount,
                maxRecommendations: settings.recommendationCount,
                rates: rates
            )
        } else {
            raw = calculate(
                holdings: holdings,
                investmentAmount: investmentAmount,
                classAllocations: globalAllocations,
                maxRecommendations: settings.recommendationCount,
                rates: rates
            )
        }

        // Suggestions are keyed by ticker (RebalancingSuggestion.id == ticker).
        // When duplicate Holdings exist (CloudKit-synced or import drift),
        // the engine produces one suggestion per Holding row → SwiftUI ForEach
        // emits "ID occurs multiple times" warnings. Keep the first by ticker;
        // engine ordering already reflects priority. The proper fix is the
        // duplicate-Holding cleanup migration, but that touches user data and
        // ships separately.
        var seen = Set<String>()
        return raw.filter { seen.insert($0.ticker).inserted }
    }
}
