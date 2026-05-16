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

    @State private var viewModel = IncomeTrendsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if let currentMonth = viewModel.currentMonth {
                    ThisMonthHeadline(
                        summary: currentMonth,
                        goal: viewModel.monthlyGoal,
                        yoy: viewModel.yoyGrowth
                    )
                }
                MonthlyTrendChart(
                    points: viewModel.monthlyHistory,
                    goal: viewModel.monthlyGoal
                )
                TopPayersList(payers: viewModel.topPayers)
                if let concentration = viewModel.concentration {
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
            viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
        }
        .task {
            viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
        }
        .onChange(of: syncService.isSyncing) { _, syncing in
            if !syncing {
                viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
            }
        }
    }
}

#Preview {
    NavigationStack {
        IncomeTrendsView()
            .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, GroveDomain.Transaction.self, UserSettings.self], inMemory: true)
    }
}
