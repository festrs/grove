import SwiftUI
import SwiftData

enum DashboardDestination: Hashable {
    case incomeHistory
    case dividendCalendar
}

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Environment(\.horizontalSizeClass) private var sizeClass

    @Query(sort: \Holding.ticker) private var holdings: [Holding]
    @Query private var settingsList: [UserSettings]

    @State private var viewModel = DashboardViewModel()

    private var settings: UserSettings? {
        settingsList.first
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        if syncService.isSyncing && viewModel.summary == nil {
                            TQLoadingView(message: "Sincronizando...")
                                .frame(maxWidth: .infinity, minHeight: 300)
                        } else if let errorMessage = viewModel.error, viewModel.summary == nil {
                            TQErrorView(
                                message: errorMessage,
                                retryAction: { viewModel.loadData(modelContext: modelContext) }
                            )
                        } else {
                            dashboardContent
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xl)
                }

                // Inspector panel on wide screens
                if sizeClass == .regular {
                    Divider()
                    InspectorPanel(
                        dividends: viewModel.nextDividends,
                        suggestions: viewModel.topSuggestions,
                        allocations: viewModel.summary?.allocationByClass ?? []
                    )
                }
            }
            .background(Color.tqBackground)
            .navigationTitle("Grove")
            .navigationDestination(for: DashboardDestination.self) { destination in
                switch destination {
                case .incomeHistory:
                    IncomeHistoryView()
                case .dividendCalendar:
                    DividendCalendarView()
                }
            }
            .refreshable {
                await syncService.syncAll(modelContext: modelContext, backendService: backendService)
                viewModel.loadData(modelContext: modelContext)
            }
        }
        .task {
            viewModel.loadData(modelContext: modelContext)
        }
        .onChange(of: holdings.count) {
            viewModel.loadData(modelContext: modelContext)
        }
        .onChange(of: syncService.isSyncing) { _, syncing in
            if !syncing {
                viewModel.loadData(modelContext: modelContext)
            }
        }
    }

    @ViewBuilder
    private var dashboardContent: some View {
        if sizeClass == .regular {
            wideDashboard
        } else {
            compactDashboard
        }
    }

    @ViewBuilder
    private var compactDashboard: some View {
        if let projection = viewModel.projection {
            NavigationLink(value: DashboardDestination.incomeHistory) {
                IncomeGaugeMeter(projection: projection)
            }
            .buttonStyle(.plain)
        }

        MonthlyActionCard(suggestions: viewModel.topSuggestions)

        if let summary = viewModel.summary {
            QuickStatsRow(summary: summary, holdingCount: holdings.count)
        }

        NavigationLink(value: DashboardDestination.dividendCalendar) {
            NextDividendCard(dividends: viewModel.nextDividends)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var wideDashboard: some View {
        // Row 1: Summary cards (4 across)
        if let summary = viewModel.summary {
            SummaryCardsRow(summary: summary, projection: viewModel.projection)
        }

        // Row 2: Hero card (gauge + action + suggestions)
        if let projection = viewModel.projection {
            HeroCard(projection: projection, suggestions: viewModel.topSuggestions)
        }

        // Row 3: Allocation drift + History bars (side-by-side)
        if let summary = viewModel.summary {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                AllocationDriftCard(allocations: summary.allocationByClass)
                    .frame(minWidth: 0, maxWidth: .infinity)

                HistoryBarChart(
                    monthlyData: [
                        ("Jan", 0), ("Fev", 0), ("Mar", 0), ("Abr", 0),
                        ("Mai", 0), ("Jun", 0), ("Jul", 0), ("Ago", 0),
                        ("Set", 0), ("Out", 0), ("Nov", 0),
                        ("Dez", summary.monthlyIncomeNet),
                    ],
                    goal: viewModel.projection?.goalMonthly ?? 10000
                )
                .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Holding.self, UserSettings.self, DividendPayment.self, Portfolio.self, Contribution.self,
        configurations: config
    )

    DashboardView()
        .modelContainer(container)
}
