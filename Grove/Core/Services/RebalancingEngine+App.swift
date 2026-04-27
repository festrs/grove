import Foundation
import SwiftData
import GroveDomain
import GroveServices
import GroveRepositories

// App-only glue: wraps the pure RebalancingEngine.calculate(...) with SwiftData
// fetching so call sites can pass just a ModelContext.
extension RebalancingEngine {
    static func suggestions(
        modelContext: ModelContext,
        investmentAmount: Money,
        rates: any ExchangeRates
    ) throws -> [RebalancingSuggestion] {
        let repo = PortfolioRepository(modelContext: modelContext)
        let holdings = try HoldingRepository(modelContext: modelContext).fetchAll()
        let settings = try repo.fetchSettings()

        let globalAllocations = settings.classAllocations

        if globalAllocations.isEmpty {
            return calculate(
                holdings: holdings,
                investmentAmount: investmentAmount,
                maxRecommendations: settings.recommendationCount,
                rates: rates
            )
        } else {
            return calculate(
                holdings: holdings,
                investmentAmount: investmentAmount,
                classAllocations: globalAllocations,
                maxRecommendations: settings.recommendationCount,
                rates: rates
            )
        }
    }
}
