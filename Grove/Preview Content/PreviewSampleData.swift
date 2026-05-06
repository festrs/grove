import Foundation
import SwiftData
import GroveDomain

struct PreviewSampleData {
    static let schema = Schema([
        Portfolio.self,
        Holding.self,
        DividendPayment.self,
        Contribution.self,
        UserSettings.self,
    ])

    @MainActor
    static var container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        populateSampleData(container.mainContext)
        return container
    }()

    @MainActor
    static func populateSampleData(_ context: ModelContext) {
        // Settings
        let settings = UserSettings(
            monthlyIncomeGoal: 10_000,
            monthlyCostOfLiving: 15_000,
            hasCompletedOnboarding: true
        )
        context.insert(settings)

        // Portfolio
        let portfolio = Portfolio(name: "Meu Portfolio")
        context.insert(portfolio)

        // Holdings
        let holdings = Holding.allSamples
        for holding in holdings {
            holding.portfolio = portfolio
            context.insert(holding)
        }

        // Dividends
        let dividends = SampleDividends.generate(for: holdings)
        for dividend in dividends {
            context.insert(dividend)
        }
    }
}
