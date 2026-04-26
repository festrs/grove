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
    var totalAllocated: Decimal = 0
    var hasCalculated = false
    var isRegistering = false
    var emptyReason: RebalancingEmptyReason?

    var investmentAmount: Decimal {
        let cleaned = investmentAmountText
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned) ?? 0
    }

    func calculate(modelContext: ModelContext, exchangeRate: Decimal = 5.12) {
        logState(prefix: "[Rebalance] calculate begin", modelContext: modelContext)
        print("[Rebalance] investmentAmount=\(investmentAmount) exchangeRate=\(exchangeRate)")

        do {
            suggestions = try RebalancingEngine.suggestions(
                modelContext: modelContext,
                investmentAmount: investmentAmount,
                exchangeRate: exchangeRate
            )
            totalAllocated = suggestions.reduce(Decimal.zero) { $0 + $1.amount }
            hasCalculated = true

            print("[Rebalance] suggestions.count=\(suggestions.count) totalAllocated=\(totalAllocated)")

            if suggestions.isEmpty {
                emptyReason = diagnoseEmpty(modelContext: modelContext)
                print("[Rebalance] empty → reason=\(String(describing: emptyReason))")
            } else {
                emptyReason = nil
            }
        } catch {
            print("[Rebalance] error=\(error)")
            suggestions = []
            hasCalculated = true
            emptyReason = .unknown
        }
    }

    private func logState(prefix: String, modelContext: ModelContext) {
        guard let holdings = try? HoldingRepository(modelContext: modelContext).fetchAll() else {
            print("\(prefix) holdings=<fetch failed>")
            return
        }
        print("\(prefix) holdings=\(holdings.count)")
        for h in holdings {
            print("  • \(h.ticker) status=\(h.statusRaw) qty=\(h.quantity) price=\(h.currentPrice) class=\(h.assetClassRaw)")
        }
        if let settings = try? PortfolioRepository(modelContext: modelContext).fetchSettings() {
            print("\(prefix) classAllocations=\(settings.classAllocations)")
        } else {
            print("\(prefix) classAllocations=<missing>")
        }
    }

    private func diagnoseEmpty(modelContext: ModelContext) -> RebalancingEmptyReason {
        let repo = PortfolioRepository(modelContext: modelContext)
        let holdingRepo = HoldingRepository(modelContext: modelContext)

        guard let settings = try? repo.fetchSettings(),
              !settings.classAllocations.isEmpty else {
            print("[Rebalance] diagnose: classAllocations missing/empty")
            return .noAllocations
        }

        guard let holdings = try? holdingRepo.fetchAll() else {
            print("[Rebalance] diagnose: fetchAll failed")
            return .unknown
        }

        let aportar = holdings.filter { $0.status == .aportar }
        let aportarWithPrice = aportar.filter { $0.currentPrice > 0 }
        print("[Rebalance] diagnose: total=\(holdings.count) aportar=\(aportar.count) aportarWithPrice=\(aportarWithPrice.count)")

        if aportarWithPrice.isEmpty {
            // Spell out which holdings were close-but-not-eligible.
            for h in aportar where h.currentPrice <= 0 {
                print("  ✗ \(h.ticker) is .aportar but currentPrice=\(h.currentPrice)")
            }
            for h in holdings where h.status != .aportar {
                print("  ✗ \(h.ticker) status=\(h.statusRaw) (not .aportar)")
            }
            return .noAportarHoldings
        }

        let totalValue = holdings.filter { $0.status != .vender }
            .reduce(Decimal.zero) { $0 + $1.currentValue }
        if totalValue <= 0 {
            print("[Rebalance] diagnose: totalValue=0 (eligible exist but no positions yet — engine should still run)")
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
                amount: suggestion.amount,
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
