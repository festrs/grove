import Foundation
import SwiftData

@Observable
final class SettingsViewModel {
    var settings: UserSettings?
    var holdingCount = 0
    var portfolioValue: Decimal = 0

    func loadData(modelContext: ModelContext) {
        let repo = PortfolioRepository(modelContext: modelContext)
        settings = try? repo.fetchSettings()
        let holdings = (try? repo.fetchAllHoldings()) ?? []
        holdingCount = holdings.count
        let summary = repo.computeSummary(holdings: holdings)
        portfolioValue = summary.totalValue
    }

    func resetOnboarding() {
        settings?.hasCompletedOnboarding = false
    }
}
