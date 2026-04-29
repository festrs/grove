import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories

// MARK: - OnboardingViewModel

@Observable
final class OnboardingViewModel {

    // MARK: - Navigation

    var currentStep: Int = 0
    static let totalSteps = 5

    // MARK: - Portfolio

    var portfolioName: String = "My Portfolio"

    // MARK: - Holdings

    var pendingHoldings: [PendingHolding] = []
    var searchQuery: String = ""
    var searchResults: [StockSearchResultDTO] = []
    var isSearching: Bool = false

    // MARK: - Target Allocations

    var targetAllocations: [AssetClassType: Decimal] = [
        .acoesBR: 30,
        .fiis: 25,
        .usStocks: 15,
        .reits: 10,
        .crypto: 5,
        .rendaFixa: 15
    ]

    // MARK: - Financial Goals

    var monthlyIncomeGoal: Decimal = AppConstants.Defaults.monthlyIncomeGoal
    var monthlyCostOfLiving: Decimal = AppConstants.Defaults.monthlyCostOfLiving

    /// Load existing allocations from UserSettings if redoing onboarding
    func loadExistingAllocations(modelContext: ModelContext) {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        guard let settings = try? modelContext.fetch(descriptor).first else { return }

        let existing = settings.classAllocations
        guard !existing.isEmpty else { return }

        for (cls, value) in existing {
            targetAllocations[cls] = Decimal(value)
        }
    }

    // MARK: - Errors

    var errorMessage: String?

    // MARK: - CSV Input

    var csvText: String = ""

    // MARK: - Computed

    var holdingCount: Int { pendingHoldings.count }
    var canAddMoreHoldings: Bool { Holding.canAddMore(currentCount: pendingHoldings.count) }

    var assetClassesInUse: [AssetClassType] {
        let used = Set(pendingHoldings.map(\.assetClass))
        return AssetClassType.allCases.filter { used.contains($0) }
    }

    var totalTargetAllocation: Decimal {
        assetClassesInUse.reduce(Decimal.zero) { sum, cls in
            sum + (targetAllocations[cls] ?? 0)
        }
    }

    var isTargetValid: Bool {
        AllocationValidator.isValid(
            Dictionary(uniqueKeysWithValues: assetClassesInUse.map { ($0, targetAllocations[$0] ?? 0) })
        )
    }

    // MARK: - Navigation Helpers

    var canAdvance: Bool {
        switch currentStep {
        case 0: return true
        case 1: return !pendingHoldings.isEmpty
        case 2: return true
        case 3: return isTargetValid
        case 4: return true
        default: return false
        }
    }

    func advance() {
        guard currentStep < Self.totalSteps - 1 else { return }
        currentStep += 1
    }

    func goBack() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }

    // MARK: - Search

    func searchTicker(query: String, service: any BackendServiceProtocol) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        errorMessage = nil
        do {
            let results = try await service.searchStocks(query: trimmed)
            searchResults = results
        } catch {
            errorMessage = "Error searching: \(error.localizedDescription)"
            searchResults = []
        }
        isSearching = false
    }

    // MARK: - Holdings Management

    func addHolding(from result: StockSearchResultDTO) {
        guard canAddMoreHoldings else {
            errorMessage = Holding.freeTierLimitMessage
            return
        }
        guard !pendingHoldings.contains(where: { $0.ticker.uppercased() == result.symbol.uppercased() }) else {
            errorMessage = "\(result.symbol) has already been added."
            return
        }

        let assetClass = AssetClassType.detect(from: result.symbol, apiType: result.type) ?? .acoesBR
        let holding = PendingHolding(
            ticker: result.symbol.uppercased(),
            displayName: result.name ?? result.symbol,
            quantity: 0,
            assetClass: assetClass,
            status: .estudo,
            currentPrice: result.priceDecimal ?? 0,
            dividendYield: 0,
            apiType: result.type
        )
        pendingHoldings.append(holding)
        errorMessage = nil
    }

    func addHolding(ticker: String) {
        guard canAddMoreHoldings else {
            errorMessage = Holding.freeTierLimitMessage
            return
        }
        let upper = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        guard !upper.isEmpty else { return }
        guard !pendingHoldings.contains(where: { $0.ticker == upper }) else {
            errorMessage = "\(upper) has already been added."
            return
        }

        let assetClass = AssetClassType.detect(from: upper) ?? .acoesBR
        let holding = PendingHolding(
            ticker: upper,
            displayName: upper,
            quantity: 0,
            assetClass: assetClass,
            status: .estudo,
            currentPrice: 0,
            dividendYield: 0
        )
        pendingHoldings.append(holding)
        errorMessage = nil
    }

    func removeHolding(at offsets: IndexSet) {
        pendingHoldings.remove(atOffsets: offsets)
    }

    func removeHolding(id: UUID) {
        pendingHoldings.removeAll { $0.id == id }
    }

    // MARK: - Auto-classify

    func autoClassifyAll() {
        for index in pendingHoldings.indices {
            // Pass the stored apiType so search-time hints (e.g. Finnhub
            // "REIT" for ticker "O") survive a re-run; without it the
            // ticker-only heuristic would clobber correct REIT/FII labels.
            if let detected = AssetClassType.detect(
                from: pendingHoldings[index].ticker,
                apiType: pendingHoldings[index].apiType
            ) {
                pendingHoldings[index].assetClass = detected
            }
        }
    }

    // MARK: - Import from AI-parsed positions

    func addHoldings(from positions: [ImportedPosition]) {
        for position in positions {
            guard canAddMoreHoldings else { break }
            let ticker = position.ticker.uppercased()
            guard !pendingHoldings.contains(where: { $0.ticker == ticker }) else { continue }

            let assetClass = position.assetClassType
            let holding = PendingHolding(
                ticker: ticker,
                displayName: position.displayName,
                quantity: Decimal(position.quantity),
                assetClass: assetClass,
                status: position.quantity > 0 ? .aportar : .estudo,
                currentPrice: Decimal(position.currentPrice),
                dividendYield: 0
            )
            pendingHoldings.append(holding)
        }
        errorMessage = nil
    }

    func importFromCSV() {
        let tickers = TickerParser.parse(csvText)
        var added = 0
        for ticker in tickers {
            guard canAddMoreHoldings else { break }
            guard !pendingHoldings.contains(where: { $0.ticker == ticker }) else { continue }
            addHolding(ticker: ticker)
            added += 1
        }
        if added > 0 {
            errorMessage = nil
        } else if tickers.isEmpty {
            errorMessage = "No tickers found. Paste one ticker per line."
        }
    }

    // MARK: - Complete Onboarding

    private static let portfolioAdjectives = [
        "Serenity", "Horizon", "Roots", "Dawn", "Harvest",
        "Crossing", "Resilience", "Season", "Breeze", "Seed"
    ]

    func completeOnboarding(
        modelContext: ModelContext,
        backendService: any BackendServiceProtocol
    ) {
        let repo = PortfolioRepository(modelContext: modelContext)
        do {
            let portfolio = try repo.saveOnboardingPortfolio(
                preferredName: portfolioName,
                nameFallbacks: Self.portfolioAdjectives.shuffled(),
                pendingHoldings: pendingHoldings,
                targetAllocations: targetAllocations,
                monthlyIncomeGoal: monthlyIncomeGoal,
                monthlyCostOfLiving: monthlyCostOfLiving
            )

            // Bootstrap price + DY for every holding the user just created so
            // the dashboard projection isn't stuck at R$0 until the next
            // sync. Keep it best-effort — onboarding completes even if the
            // network is flaky. Skip refreshDividendsAfterTransaction here:
            // bootstrap contributions are dated `.now`, so a since-scoped
            // scrape would be a no-op anyway. Users can backfill via the
            // manual refresh button per asset class.
            let snapshot = portfolio.holdings
            let svc = backendService
            let ctx = modelContext
            let bootstrap = TickerBootstrapService()
            Task { @MainActor in
                await bootstrap.bootstrap(holdings: snapshot, backendService: svc)
                try? ctx.save()
            }
        } catch {
            errorMessage = "Error saving: \(error.localizedDescription)"
        }
    }
}
