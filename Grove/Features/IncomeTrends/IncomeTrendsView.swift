import SwiftUI
import SwiftData
import GroveDomain
import GroveServices

/// Income Trends — answers "how is my passive income evolving over time?".
/// Deliberately disjoint from the Dashboard gauge (this calendar month) and
/// the IncomeHistory window cards (per-window totals): every section here
/// surfaces signal that exists nowhere else in the app — TTM growth, monthly
/// trend bars, top payers ranked by income, and concentration risk.
struct IncomeTrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService
    @Environment(\.backendService) private var backendService
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    @Query private var holdings: [Holding]
    @Query private var allSettings: [UserSettings]

    private static let chartLastN = 12
    private static let chartLookahead = 3
    private static let topPayersLimit = 5
    private static let concentrationTopN = 3

    private var currentMonth: IncomeWindowSummary {
        IncomeAggregator.summary(
            holdings: holdings, window: .month,
            in: displayCurrency, rates: rates
        )
    }

    private var monthlyGoal: Money? {
        allSettings.first.map { $0.monthlyIncomeGoalMoney.converted(to: displayCurrency, using: rates) }
    }

    private var monthlyHistory: [IncomeAggregator.MonthlyIncomePoint] {
        IncomeAggregator.monthlyHistory(
            holdings: holdings,
            lastN: Self.chartLastN, lookahead: Self.chartLookahead,
            in: displayCurrency, rates: rates
        )
    }

    private var yoyGrowth: IncomeAggregator.YoYGrowth? {
        IncomeAggregator.yoyGrowth(holdings: holdings, in: displayCurrency, rates: rates)
    }

    private var topPayers: [IncomeAggregator.TopPayer] {
        IncomeAggregator.topPayers(
            holdings: holdings, limit: Self.topPayersLimit,
            in: displayCurrency, rates: rates
        )
    }

    private var concentration: IncomeAggregator.Concentration? {
        IncomeAggregator.concentration(
            holdings: holdings, topN: Self.concentrationTopN,
            in: displayCurrency, rates: rates
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                ThisMonthHeadline(
                    summary: currentMonth,
                    goal: monthlyGoal,
                    yoy: yoyGrowth
                )
                MonthlyTrendChart(
                    points: monthlyHistory,
                    goal: monthlyGoal
                )
                TopPayersList(payers: topPayers)
                if let concentration {
                    ConcentrationBar(concentration: concentration, topN: 3)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: Theme.Layout.maxContentWidth)
        }
        .navigationTitle("Income trends")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // Top-payer rows are `NavigationLink(value: payer.holdingID)` —
        // resolves to the holding detail using the same contract the
        // Portfolio screens already register.
        .navigationDestination(for: PersistentIdentifier.self) { id in
            HoldingDetailView(holdingID: id)
        }
        .background(Color.tqBackground)
        .refreshable {
            await syncService.syncAll(modelContext: modelContext, backendService: backendService)
            try? await syncService.syncDividends(modelContext: modelContext, backendService: backendService)
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        IncomeTrendsView()
            .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, GroveDomain.Transaction.self, UserSettings.self], inMemory: true)
    }
}
