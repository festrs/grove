import SwiftUI
import SwiftData

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

    var portfolioName: String = "Meu Portfolio"

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
            errorMessage = "Erro ao buscar: \(error.localizedDescription)"
            searchResults = []
        }
        isSearching = false
    }

    // MARK: - Holdings Management

    func addHolding(from result: StockSearchResultDTO, quantity: Decimal) {
        guard canAddMoreHoldings else {
            errorMessage = "Limite de \(AppConstants.freeTierMaxHoldings) ativos no plano gratuito."
            return
        }
        guard !pendingHoldings.contains(where: { $0.ticker.uppercased() == result.symbol.uppercased() }) else {
            errorMessage = "\(result.symbol) ja foi adicionado."
            return
        }

        let assetClass = AssetClassType.detect(from: result.symbol) ?? .acoesBR
        let holding = PendingHolding(
            ticker: result.symbol.uppercased(),
            displayName: result.name ?? result.symbol,
            quantity: quantity,
            assetClass: assetClass,
            status: .aportar,
            currentPrice: 0,
            dividendYield: 0
        )
        pendingHoldings.append(holding)
        errorMessage = nil
    }

    func addHolding(ticker: String, quantity: Decimal) {
        guard canAddMoreHoldings else {
            errorMessage = "Limite de \(AppConstants.freeTierMaxHoldings) ativos no plano gratuito."
            return
        }
        let upper = ticker.uppercased().trimmingCharacters(in: .whitespaces)
        guard !upper.isEmpty else { return }
        guard !pendingHoldings.contains(where: { $0.ticker == upper }) else {
            errorMessage = "\(upper) ja foi adicionado."
            return
        }

        let assetClass = AssetClassType.detect(from: upper) ?? .acoesBR
        let holding = PendingHolding(
            ticker: upper,
            displayName: upper,
            quantity: quantity,
            assetClass: assetClass,
            status: .aportar,
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

    // MARK: - CSV Parsing

    func parseCSV(_ text: String) -> [(String, Decimal)] {
        var results: [(String, Decimal)] = []
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Support separators: comma, semicolon, tab
            let separators: [String] = [",", ";", "\t"]
            var parts: [String]?
            for sep in separators {
                let split = trimmed.components(separatedBy: sep)
                if split.count >= 2 {
                    parts = split
                    break
                }
            }
            guard let components = parts, components.count >= 2 else { continue }

            let ticker = components[0].trimmingCharacters(in: .whitespaces).uppercased()
            let qtyString = components[1]
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
            guard !ticker.isEmpty, let qty = Decimal(string: qtyString), qty > 0 else { continue }
            results.append((ticker, qty))
        }
        return results
    }

    func importFromCSV() {
        let parsed = parseCSV(csvText)
        var added = 0
        for (ticker, qty) in parsed {
            guard canAddMoreHoldings else { break }
            guard !pendingHoldings.contains(where: { $0.ticker == ticker }) else { continue }
            addHolding(ticker: ticker, quantity: qty)
            added += 1
        }
        if added > 0 {
            errorMessage = nil
        } else if parsed.isEmpty {
            errorMessage = "Nenhum ativo encontrado. Use o formato: TICKER, QUANTIDADE"
        }
    }

    // MARK: - Complete Onboarding

    func completeOnboarding(modelContext: ModelContext) {
        let portfolio = Portfolio(name: portfolioName)
        modelContext.insert(portfolio)

        for pending in pendingHoldings {
            let targetPct = targetAllocations[pending.assetClass] ?? 0
            // Distribute target percent evenly among holdings of the same class
            let classCount = Decimal(pendingHoldings.filter { $0.assetClass == pending.assetClass }.count)
            let holdingTarget = classCount > 0 ? targetPct / classCount : 0

            let holding = Holding(
                ticker: pending.ticker,
                displayName: pending.displayName,
                quantity: pending.quantity,
                averagePrice: pending.currentPrice,
                currentPrice: pending.currentPrice,
                dividendYield: pending.dividendYield,
                assetClass: pending.assetClass,
                status: pending.status,
                targetPercent: holdingTarget
            )
            holding.portfolio = portfolio
            modelContext.insert(holding)
        }

        // Update existing settings instead of creating a duplicate
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        let existingSettings = (try? modelContext.fetch(descriptor))?.first

        if let settings = existingSettings {
            settings.monthlyIncomeGoal = monthlyIncomeGoal
            settings.monthlyCostOfLiving = monthlyCostOfLiving
            settings.hasCompletedOnboarding = true
        } else {
            let settings = UserSettings(
                monthlyIncomeGoal: monthlyIncomeGoal,
                monthlyCostOfLiving: monthlyCostOfLiving,
                hasCompletedOnboarding: true
            )
            modelContext.insert(settings)
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Erro ao salvar: \(error.localizedDescription)"
        }
    }
}
