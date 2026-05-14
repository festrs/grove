import Foundation
import SwiftData
import GroveDomain
import GroveServices
import GroveRepositories

/// View-state for the Income Trends screen.
///
/// Anchors on the **same paid + projected window the dashboard gauge uses**
/// (`IncomeAggregator.summary(window: .month)`) so the headline number on
/// this screen matches what the user sees on the gauge — one mental model
/// across the app. The chart, top payers, and concentration provide the
/// historical context the gauge can't show.
@Observable
@MainActor
final class IncomeTrendsViewModel {
    /// Paid + projected for the current calendar month — the same window
    /// `IncomeProjector.project` reads for the dashboard gauge.
    var currentMonth: IncomeWindowSummary?
    /// User's monthly Freedom Plan goal, in `displayCurrency`. Drives the
    /// goal line on the chart and the "% of goal" stat in the headline.
    var monthlyGoal: Money?

    var monthlyHistory: [IncomeAggregator.MonthlyIncomePoint] = []
    var yoyGrowth: IncomeAggregator.YoYGrowth?
    var topPayers: [IncomeAggregator.TopPayer] = []
    var concentration: IncomeAggregator.Concentration?
    var isLoading = false

    /// 12 strictly-past months + 3 future projected.
    private static let chartLastN = 12
    private static let chartLookahead = 3
    private static let topPayersLimit = 5
    private static let concentrationTopN = 3

    func loadData(modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        isLoading = true
        defer { isLoading = false }

        do {
            let portfolioRepo = PortfolioRepository(modelContext: modelContext)
            let holdings = try portfolioRepo.fetchAllHoldings()
            let settings = try? portfolioRepo.fetchSettings()

            currentMonth = IncomeAggregator.summary(
                holdings: holdings, window: .month,
                in: displayCurrency, rates: rates
            )

            monthlyGoal = settings.map { $0.monthlyIncomeGoalMoney.converted(to: displayCurrency, using: rates) }

            monthlyHistory = IncomeAggregator.monthlyHistory(
                holdings: holdings,
                lastN: Self.chartLastN, lookahead: Self.chartLookahead,
                in: displayCurrency, rates: rates
            )

            yoyGrowth = IncomeAggregator.yoyGrowth(
                holdings: holdings, in: displayCurrency, rates: rates
            )

            topPayers = IncomeAggregator.topPayers(
                holdings: holdings, limit: Self.topPayersLimit,
                in: displayCurrency, rates: rates
            )

            concentration = IncomeAggregator.concentration(
                holdings: holdings, topN: Self.concentrationTopN,
                in: displayCurrency, rates: rates
            )
        } catch {
            currentMonth = nil
            monthlyGoal = nil
            monthlyHistory = []
            yoyGrowth = nil
            topPayers = []
            concentration = nil
        }
    }
}
