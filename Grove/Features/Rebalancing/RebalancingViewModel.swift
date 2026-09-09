import Foundation
import SwiftData
import GroveDomain
import GroveServices
import GroveRepositories

@Observable
final class RebalancingViewModel {
    var investmentAmountText = ""
    var suggestions: [RebalancingSuggestion] = []
    var totalAllocated: Money = .zero(in: .brl)
    var hasCalculated = false
    var isRegistering = false
    var emptyReason: RebalancingEmptyReason?
    var editedShares: [String: Int] = [:]

    var investmentAmountDecimal: Decimal {
        let cleaned = investmentAmountText
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned) ?? 0
    }

    func investmentAmount(in currency: Currency) -> Money {
        Money(amount: investmentAmountDecimal, currency: currency)
    }

    func effectiveShares(for suggestion: RebalancingSuggestion) -> Int {
        editedShares[suggestion.ticker] ?? suggestion.sharesToBuy
    }

    func setShares(_ value: Int, for suggestion: RebalancingSuggestion) {
        editedShares[suggestion.ticker] = max(0, value)
    }

    func effectiveAmount(for suggestion: RebalancingSuggestion) -> Money {
        guard suggestion.sharesToBuy > 0 else { return suggestion.amount }
        let perShare = suggestion.amount.amount / Decimal(suggestion.sharesToBuy)
        return Money(amount: Decimal(effectiveShares(for: suggestion)) * perShare, currency: suggestion.amount.currency)
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
            editedShares = [:]

            emptyReason = suggestions.isEmpty ? RebalancingEngine.diagnoseEmpty(modelContext: modelContext) : nil
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
            let shares = effectiveShares(for: suggestion)
            guard shares > 0 else { continue }

            let ticker = suggestion.ticker
            let descriptor = FetchDescriptor<Holding>(
                predicate: #Predicate { $0.ticker == ticker }
            )
            guard let holding = try? modelContext.fetch(descriptor).first else { continue }

            let transaction = Transaction(
                date: .now,
                amount: Decimal(shares) * holding.currentPrice,
                shares: Decimal(shares),
                pricePerShare: holding.currentPrice
            )
            transaction.holding = holding
            modelContext.insert(transaction)

            holding.recalculateFromTransactions()
        }

        suggestions = []
        investmentAmountText = ""
        hasCalculated = false
        editedShares = [:]
    }
}
