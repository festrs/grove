import Foundation
import SwiftData

enum RebalancingEmptyReason {
    case noAportarHoldings
    case noPortfolioValue
    case noAllocations
    case unknown
}

@Observable
final class RebalancingViewModel {
    var investmentAmountText = ""
    var suggestions: [RebalancingSuggestion] = []
    var totalAllocated: Money = .zero(in: .brl)
    var hasCalculated = false
    var isRegistering = false
    var emptyReason: RebalancingEmptyReason?

    var investmentAmountDecimal: Decimal {
        let cleaned = investmentAmountText
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned) ?? 0
    }

    func investmentAmount(in currency: Currency) -> Money {
        Money(amount: investmentAmountDecimal, currency: currency)
    }

    func calculate(modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        let amount = investmentAmount(in: displayCurrency)

        do {
            suggestions = try RebalancingEngine.suggestions(
                modelContext: modelContext,
                investmentAmount: amount,
                rates: rates
            )
            let allocated = suggestions.map { $0.amount }.sum(in: displayCurrency, using: rates)
            totalAllocated = allocated
            hasCalculated = true

            if suggestions.isEmpty {
                emptyReason = diagnoseEmpty(modelContext: modelContext)
            } else {
                emptyReason = nil
            }
        } catch {
            suggestions = []
            hasCalculated = true
            emptyReason = .unknown
        }
    }

    private func diagnoseEmpty(modelContext: ModelContext) -> RebalancingEmptyReason {
        let repo = PortfolioRepository(modelContext: modelContext)
        let holdingRepo = HoldingRepository(modelContext: modelContext)

        guard let settings = try? repo.fetchSettings(),
              !settings.classAllocations.isEmpty else {
            return .noAllocations
        }

        guard let holdings = try? holdingRepo.fetchAll() else {
            return .unknown
        }

        let aportar = holdings.filter { $0.status == .aportar }
        let aportarWithPrice = aportar.filter { $0.currentPrice > 0 }

        if aportarWithPrice.isEmpty {
            return .noAportarHoldings
        }

        let totalValue = holdings.filter { $0.status != .vender }
            .reduce(Decimal.zero) { $0 + $1.currentValue }
        if totalValue <= 0 {
            return .noPortfolioValue
        }

        return .unknown
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
                amount: suggestion.amount.amount,
                shares: Decimal(suggestion.sharesToBuy),
                pricePerShare: holding.currentPrice
            )
            contribution.holding = holding
            modelContext.insert(contribution)

            holding.recalculateFromContributions()
        }

        suggestions = []
        investmentAmountText = ""
        hasCalculated = false
    }
}
