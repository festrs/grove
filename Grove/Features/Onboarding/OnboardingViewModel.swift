import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories
import GroveServices

// MARK: - OnboardingViewModel

@Observable
final class OnboardingViewModel {

    // MARK: - Navigation

    var currentStep: Int = 0
    /// Sub-step inside the Freedom Plan step (currentStep == 1). 0..<5.
    var freedomPlanSubStep: Int = 0
    static let totalSteps = 6
    static let freedomPlanSubStepCount = 5

    /// 0 → 5. Order matters: the user sees the goal first (welcome →
    /// freedomPlan), then learns *how* Grove will get them there
    /// (howGroveWorks bridge → strategy allocations), then optionally
    /// brings in their existing holdings, then lands on a recap.
    enum Step: Int {
        case welcome = 0
        case freedomPlan = 1
        case howGroveWorks = 2
        case strategy = 3
        case holdings = 4
        case recap = 5
    }

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

    // MARK: - Freedom Plan

    var monthlyCostOfLiving: Decimal = AppConstants.Defaults.monthlyCostOfLiving
    var costOfLivingCurrency: Currency = .brl
    var targetFIYear: Int = Calendar.current.component(.year, from: .now) + 20
    var fiIncomeMode: FIIncomeMode = .essentials
    var monthlyContributionCapacity: Decimal = 0
    var contributionCurrency: Currency = .brl
    var fiCurrencyMixBRLPercent: Decimal = 100

    /// Computed lazily on the reveal screen. Requires display currency + rates
    /// from the environment, so callers pass those in.
    func freedomNumber(displayCurrency: Currency, rates: any ExchangeRates) -> Money {
        FreedomPlanCalculator.freedomNumber(
            monthlyCostOfLiving: Money(amount: monthlyCostOfLiving, currency: costOfLivingCurrency),
            incomeMode: fiIncomeMode,
            currencyMixBRLPercent: fiCurrencyMixBRLPercent,
            displayCurrency: displayCurrency,
            rates: rates
        ).total
    }

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
        AssetClassType.allCases.reduce(Decimal.zero) { sum, cls in
            sum + (targetAllocations[cls] ?? 0)
        }
    }

    var isTargetValid: Bool {
        AllocationValidator.isValid(targetAllocations)
    }

    // MARK: - Navigation Helpers

    var canAdvance: Bool {
        guard let step = Step(rawValue: currentStep) else { return false }
        switch step {
        case .welcome: return true
        case .freedomPlan: return canAdvanceFreedomPlanSubStep
        case .howGroveWorks: return true
        case .strategy: return isTargetValid
        // Holdings is always advanceable — empty list means the user
        // chose to skip and add tickers later from the Portfolio tab.
        case .holdings: return true
        case .recap: return true
        }
    }

    /// Per-screen validation inside the Freedom Plan step.
    var canAdvanceFreedomPlanSubStep: Bool {
        switch freedomPlanSubStep {
        case 0: return monthlyCostOfLiving > 0
        case 1: return targetFIYear >= Calendar.current.component(.year, from: .now)
        case 2: return true // mode picker has a default
        case 3: return true // capacity allowed to be 0 (filled later in Settings)
        case 4: return true // reveal
        default: return false
        }
    }

    func advance() {
        guard let step = Step(rawValue: currentStep) else { return }
        if step == .freedomPlan && freedomPlanSubStep < Self.freedomPlanSubStepCount - 1 {
            freedomPlanSubStep += 1
            return
        }
        guard currentStep < Self.totalSteps - 1 else { return }
        currentStep += 1
    }

    func goBack() {
        guard let step = Step(rawValue: currentStep) else { return }
        if step == .freedomPlan && freedomPlanSubStep > 0 {
            freedomPlanSubStep -= 1
            return
        }
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
            let results = try await service.searchStocks(query: trimmed, assetClass: nil)
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

    /// Update the priority for a pending holding by id. The view binds
    /// to this so the inline 1–5 stepper writes through without the
    /// ForEach having to re-anchor the index on every render.
    func setTargetPercent(id: UUID, value: Decimal) {
        guard let index = pendingHoldings.firstIndex(where: { $0.id == id }) else { return }
        pendingHoldings[index].targetPercent = value
    }

    /// Append a pre-populated draft (from `AddAssetDetailSheet` in
    /// `.onboarding` mode) with the same dedupe/limit guards as
    /// `addHolding(from:)`.
    func appendPending(_ pending: PendingHolding) {
        guard canAddMoreHoldings else {
            errorMessage = Holding.freeTierLimitMessage
            return
        }
        guard !pendingHoldings.contains(where: { $0.ticker.uppercased() == pending.ticker.uppercased() }) else {
            errorMessage = "\(pending.ticker) has already been added."
            return
        }
        pendingHoldings.append(pending)
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
        backendService: any BackendServiceProtocol,
        displayCurrency: Currency = .brl,
        rates: any ExchangeRates = StaticRates(brlPerUsd: 5)
    ) {
        let repo = PortfolioRepository(modelContext: modelContext)
        do {
            let plan = PortfolioRepository.FreedomPlanInput(
                monthlyCostOfLiving: monthlyCostOfLiving,
                costOfLivingCurrency: costOfLivingCurrency,
                targetFIYear: targetFIYear,
                incomeMode: fiIncomeMode,
                monthlyContributionCapacity: monthlyContributionCapacity,
                contributionCurrency: contributionCurrency,
                currencyMixBRLPercent: fiCurrencyMixBRLPercent,
                freedomNumber: freedomNumber(displayCurrency: displayCurrency, rates: rates)
            )
            let portfolio = try repo.saveOnboardingPortfolio(
                preferredName: portfolioName,
                nameFallbacks: Self.portfolioAdjectives.shuffled(),
                pendingHoldings: pendingHoldings,
                targetAllocations: targetAllocations,
                freedomPlan: plan
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
            let trackPairs = snapshot
                .filter { !$0.isCustom }
                .map { (symbol: $0.ticker, assetClass: $0.assetClass.rawValue) }
            Task { @MainActor in
                if !trackPairs.isEmpty {
                    try? await svc.syncTrackedSymbols(pairs: trackPairs)
                }
                await bootstrap.bootstrap(holdings: snapshot, backendService: svc)
                try? ctx.save()
            }
        } catch {
            errorMessage = "Error saving: \(error.localizedDescription)"
        }
    }
}
