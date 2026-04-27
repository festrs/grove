import SwiftUI
import SwiftData
import GroveDomain
import GroveServices
import GroveRepositories

enum DashboardDestination: Hashable {
    case incomeHistory
    case dividendCalendar
}

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    @Query(sort: \Holding.ticker) private var holdings: [Holding]
    @Query private var settingsList: [UserSettings]

    @State private var viewModel = DashboardViewModel()

    private static let fxTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    @ViewBuilder
    private var fxCaption: some View {
        if let store = rates as? RateStore {
            if let updated = store.lastUpdated {
                Text("FX as of \(Self.fxTimeFormatter.string(from: updated))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("FX unavailable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

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
                                retryAction: { viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }
                            )
                        } else {
                            dashboardContent
                            fxCaption
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, Theme.Spacing.sm)
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
                viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
            }
        }
        .task {
            viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
        }
        .onChange(of: holdings.count) {
            viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
        }
        .onChange(of: syncService.isSyncing) { _, syncing in
            if !syncing {
                viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
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
                        ("Jan", .zero(in: displayCurrency)), ("Fev", .zero(in: displayCurrency)),
                        ("Mar", .zero(in: displayCurrency)), ("Abr", .zero(in: displayCurrency)),
                        ("Mai", .zero(in: displayCurrency)), ("Jun", .zero(in: displayCurrency)),
                        ("Jul", .zero(in: displayCurrency)), ("Ago", .zero(in: displayCurrency)),
                        ("Set", .zero(in: displayCurrency)), ("Out", .zero(in: displayCurrency)),
                        ("Nov", .zero(in: displayCurrency)),
                        ("Dez", summary.monthlyIncomeNet),
                    ],
                    goal: viewModel.projection?.goalMonthly ?? Money(amount: 10000, currency: displayCurrency)
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
