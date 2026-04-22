import Foundation
import SwiftData

@Observable
final class RebalancingViewModel {
    var investmentAmountText = ""
    var suggestions: [RebalancingSuggestion] = []
    var totalAllocated: Decimal = 0
    var hasCalculated = false
    var isRegistering = false

    var investmentAmount: Decimal {
        let cleaned = investmentAmountText
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned) ?? 0
    }

    func calculate(modelContext: ModelContext, exchangeRate: Decimal = 5.12) {
        do {
            suggestions = try RebalancingEngine.suggestions(
                modelContext: modelContext,
                investmentAmount: investmentAmount,
                exchangeRate: exchangeRate
            )
            totalAllocated = suggestions.reduce(Decimal.zero) { $0 + $1.amount }
            hasCalculated = true
        } catch {
            suggestions = []
        }
    }

    func registerContributions(modelContext: ModelContext) {
        isRegistering = true
        defer { isRegistering = false }

        for suggestion in suggestions {
            let ticker = suggestion.ticker
            let descriptor = FetchDescriptor<Holding>(
                predicate: #Predicate { $0.ticker == ticker }
            )
            guard let holding = try? modelContext.fetch(descriptor).first else { continue }

            let contribution = Contribution(
                date: .now,
                amount: suggestion.amount,
                shares: Decimal(suggestion.sharesToBuy),
                pricePerShare: holding.currentPrice
            )
            contribution.holding = holding
            modelContext.insert(contribution)

            holding.quantity += Decimal(suggestion.sharesToBuy)
        }

        suggestions = []
        investmentAmountText = ""
        hasCalculated = false
    }
}
