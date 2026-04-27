import SwiftUI
import SwiftData
import GroveDomain

// MARK: - PendingHolding

struct PendingHolding: Identifiable {
    let id = UUID()
    var ticker: String
    var displayName: String
    var quantity: Decimal
    var assetClass: AssetClassType
    var status: HoldingStatus
    var currentPrice: Decimal
    var dividendYield: Decimal
}

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
    var canAddMoreHoldings: Bool { pendingHoldings.count < AppConstants.freeTierMaxHoldings }

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
        let total = totalTargetAllocation
        return total >= 99 && total <= 101
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
            dividendYield: 0
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
            if let detected = AssetClassType.detect(from: pendingHoldings[index].ticker) {
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

    // MARK: - Ticker Parsing (used by tests)

    func parseTickers(_ text: String) -> [String] {
        var results: [String] = []
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            var ticker = trimmed
            for sep in [",", ";", "\t"] {
                let split = trimmed.components(separatedBy: sep)
                if split.count >= 2 {
                    ticker = split[0].trimmingCharacters(in: .whitespaces)
                    break
                }
            }

            let upper = ticker.uppercased()
            guard !upper.isEmpty, upper.count <= 10 else { continue }
            guard upper.contains(where: { $0.isLetter }) else { continue }
            results.append(upper)
        }
        return results
    }

    func importFromCSV() {
        let tickers = parseTickers(csvText)
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

    func completeOnboarding(modelContext: ModelContext) {
        // Generate unique portfolio name
        let portfolioDescriptor = FetchDescriptor<Portfolio>()
        let existing = (try? modelContext.fetch(portfolioDescriptor)) ?? []
        let existingNames = Set(existing.map(\.name))

        var finalName = portfolioName
        if existingNames.contains(finalName) {
            let shuffled = Self.portfolioAdjectives.shuffled()
            finalName = shuffled.first { !existingNames.contains($0) } ?? "Portfolio \(existing.count + 1)"
        }

        let portfolio = Portfolio(name: finalName)
        modelContext.insert(portfolio)

        for pending in pendingHoldings {
            let holding = Holding(
                ticker: pending.ticker,
                displayName: pending.displayName,
                currentPrice: pending.currentPrice,
                dividendYield: pending.dividendYield,
                assetClass: pending.assetClass,
                status: pending.status
            )
            holding.portfolio = portfolio
            modelContext.insert(holding)

            // Create initial buy contribution if the user has a position
            if pending.quantity > 0 {
                let contribution = Contribution(
                    date: .now,
                    amount: pending.quantity * pending.currentPrice,
                    shares: pending.quantity,
                    pricePerShare: pending.currentPrice
                )
                contribution.holding = holding
                modelContext.insert(contribution)
                holding.recalculateFromContributions()
            }
        }

        // Update existing settings instead of creating a duplicate
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        let existingSettings = (try? modelContext.fetch(descriptor))?.first

        // Persist only allocations for classes the user actually has holdings in.
        // SetTargets validates the in-use total against 100, so writing the full
        // dict (with untouched defaults for unused classes) was producing sums >100.
        let usedClasses = Set(pendingHoldings.map(\.assetClass))
        let doubleAllocations = Dictionary(uniqueKeysWithValues:
            targetAllocations
                .filter { usedClasses.contains($0.key) }
                .map { ($0.key, NSDecimalNumber(decimal: $0.value).doubleValue) }
        )

        if let settings = existingSettings {
            settings.monthlyIncomeGoal = monthlyIncomeGoal
            settings.monthlyCostOfLiving = monthlyCostOfLiving
            settings.classAllocations = doubleAllocations
            settings.hasCompletedOnboarding = true
        } else {
            let settings = UserSettings(
                monthlyIncomeGoal: monthlyIncomeGoal,
                monthlyCostOfLiving: monthlyCostOfLiving,
                hasCompletedOnboarding: true
            )
            settings.classAllocations = doubleAllocations
            modelContext.insert(settings)
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Error saving: \(error.localizedDescription)"
        }
    }
}
