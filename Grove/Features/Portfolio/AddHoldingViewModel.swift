import Foundation
import SwiftData

@Observable
final class AddHoldingViewModel {
    var searchQuery = ""
    var searchResults: [StockSearchResultDTO] = []
    var isSearching = false

    var ticker = ""
    var displayName = ""
    var quantityText = ""
    var assetClass: AssetClassType = .acoesBR
    var status: HoldingStatus = .aportar
    var currentPrice: Decimal = 0
    var dividendYield: Decimal = 0
    var error: String?

    private var searchTask: Task<Void, Never>?

    func search(query: String, service: any BackendServiceProtocol) async {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }

        searchTask = Task {
            // Debounce
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            isSearching = true
            defer { isSearching = false }

            do {
                searchResults = try await service.searchStocks(query: trimmed)
            } catch {
                searchResults = []
            }
        }
    }

    func selectSearchResult(_ result: StockSearchResultDTO, service: any BackendServiceProtocol) {
        ticker = result.symbol
        displayName = result.name ?? result.symbol
        if let detected = AssetClassType.detect(from: result.symbol) {
            assetClass = detected
        }
        searchResults = []
        searchQuery = result.symbol

        // Fetch current price
        Task {
            do {
                let quote = try await service.fetchStockQuote(symbol: result.symbol)
                currentPrice = quote.price.decimalAmount
            } catch {
                // Price will remain 0 — user can still add
            }
        }
    }

    func save(modelContext: ModelContext, backendService: any BackendServiceProtocol) -> Bool {
        guard !ticker.isEmpty else {
            error = "Please enter a ticker."
            return false
        }
        guard let qty = Decimal(string: quantityText), qty > 0 else {
            error = "Please enter a valid quantity."
            return false
        }

        guard Holding.canAddMore(modelContext: modelContext) else {
            error = Holding.freeTierLimitMessage
            return false
        }

        let holding = Holding(
            ticker: ticker.uppercased(),
            displayName: displayName,
            quantity: qty,
            averagePrice: currentPrice,
            currentPrice: currentPrice,
            dividendYield: dividendYield,
            assetClass: assetClass,
            status: status
        )

        // Attach to default portfolio
        var portfolioDescriptor = FetchDescriptor<Portfolio>(sortBy: [SortDescriptor(\.createdAt)])
        portfolioDescriptor.fetchLimit = 1
        if let portfolio = try? modelContext.fetch(portfolioDescriptor).first {
            holding.portfolio = portfolio
        }

        modelContext.insert(holding)

        let sym = holding.ticker
        let cls = holding.assetClass.rawValue
        Task { try? await backendService.trackSymbol(symbol: sym, assetClass: cls) }

        return true
    }
}
