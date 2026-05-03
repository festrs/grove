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
    @Query private var portfolios: [Portfolio]
    @Query private var settingsList: [UserSettings]

    @State private var viewModel = DashboardViewModel()
    @State private var isLandscape: Bool = false

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

                // Inspector panel at regular width in landscape only (iPad
                // landscape and Mac). iPad portrait reports regular too, so we
                // also gate on orientation; portrait falls back to the inline
                // cards in compactDashboard.
                if sizeClass == .regular && isLandscape {
                    Divider()
                    InspectorPanel(
                        dividends: viewModel.nextDividends,
                        suggestions: viewModel.topSuggestions,
                        allocations: viewModel.summary?.allocationByClass ?? []
                    )
                }
            }
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.size.width > proxy.size.height
            } action: { newValue in
                isLandscape = newValue
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
            QuickStatsRow(summary: summary, holdingCount: holdings.count, portfolioCount: portfolios.count)
        }

        NavigationLink(value: DashboardDestination.dividendCalendar) {
            NextDividendCard(dividends: viewModel.nextDividends)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var wideDashboard: some View {
        // Row 1: KPI summary cards.
        if let summary = viewModel.summary {
            SummaryCardsRow(summary: summary, projection: viewModel.projection, portfolioCount: portfolios.count)
        }

        // Row 2: Hero card (gauge + action + suggestions).
        if let projection = viewModel.projection {
            HeroCard(projection: projection, suggestions: viewModel.topSuggestions)
        }

        // Row 3: Adaptive grid — allocation drift + upcoming dividends.
        // LazyVGrid reflows: 1 column on narrow regular widths (iPad
        // portrait), 2 columns on wider widths (iPad landscape, Mac).
        if let summary = viewModel.summary {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 360), spacing: Theme.Spacing.md)],
                spacing: Theme.Spacing.md
            ) {
                AllocationDriftCard(allocations: summary.allocationByClass)
                NavigationLink(value: DashboardDestination.dividendCalendar) {
                    NextDividendCard(dividends: viewModel.nextDividends)
                }
                .buttonStyle(.plain)
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
