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

    @Query(sort: \Holding.ticker) private var holdings: [Holding]
    @Query private var settingsList: [UserSettings]

    @State private var viewModel = DashboardViewModel()

    private var settings: UserSettings? {
        settingsList.first
    }

    var body: some View {
        NavigationStack {
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
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Color.tqBackground)
            .navigationTitle("Tranquilidade")
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
