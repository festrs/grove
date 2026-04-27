import Foundation
import SwiftData
import GroveDomain

@Observable
final class HoldingDetailViewModel {
    var holding: Holding?
    var isLoading = false
    var error: String?

    func loadHolding(id: PersistentIdentifier, modelContext: ModelContext) {
        holding = modelContext.model(for: id) as? Holding
    }

    func updatePrice(backendService: any BackendServiceProtocol) async {
        guard let holding else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let quote = try await backendService.fetchStockQuote(symbol: holding.ticker)
            holding.currentPrice = quote.price.decimalAmount
            holding.lastPriceUpdate = .now
            if let mc = quote.marketCap {
                holding.marketCap = mc.amount
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
