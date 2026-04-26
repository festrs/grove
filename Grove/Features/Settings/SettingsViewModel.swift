import Foundation
import SwiftData

@Observable
final class SettingsViewModel {
    var settings: UserSettings?
    var holdingCount = 0
    var portfolioValue: Money = .zero(in: .brl)

    func loadData(modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        let repo = PortfolioRepository(modelContext: modelContext)
        settings = try? repo.fetchSettings()
        let holdings = (try? repo.fetchAllHoldings()) ?? []
        holdingCount = holdings.count
        let summary = repo.computeSummary(
            holdings: holdings,
            displayCurrency: displayCurrency,
            rates: rates
        )
        portfolioValue = summary.totalValue
    }

    func resetOnboarding() {
        settings?.hasCompletedOnboarding = false
    }
}
