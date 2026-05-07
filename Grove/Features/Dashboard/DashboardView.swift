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
    // Observe the dividend + contribution stores so the gauge refreshes when
    // iCloud fans new payments in after launch or a buy/sell updates a
    // holding's share count. Without these, `loadData` only re-runs when the
    // holdings *count* changes — which it doesn't on a dividend or contribution
    // arrival — and the projection sticks at whatever it computed at launch.
    @Query private var dividends: [DividendPayment]
    @Query private var contributions: [Contribution]

    @State private var viewModel = DashboardViewModel()
    @State private var isLandscape: Bool = false
    /// Coalesces the rapid burst of `loadData` triggers on cold launch
    /// (iCloud fans Holdings / Contributions / DividendPayments in over a few
    /// render cycles) and pull-to-refresh (`.refreshable` + the `isSyncing`
    /// onChange both fire). One `send()` per signal; the consumer runs
    /// `loadData` once after the window settles.
    @State private var reloader = ReloadDebouncer()

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
                    // On iPhone, route through the Dividends Hub so the user
                    // also has access to income history (the sidebar handles
                    // that on iPad/Mac).
                    if sizeClass == .compact {
                        DividendsHubView()
                    } else {
                        DividendCalendarView()
                    }
                }
            }
            .refreshable {
                // Run on an unstructured Task so the URL request isn't
                // cancelled by SwiftUI's pull-to-refresh gesture lifecycle.
                // The cancelled `mobile/quotes` request would surface as a
                // 4ms `URLError.cancelled` followed by a ~5s freeze while
                // URLSession completes cleanup, then a silent failure.
                let work = Task { @MainActor in
                    await syncService.syncAll(modelContext: modelContext, backendService: backendService)
                    // The trailing `isSyncing` onChange will also send a
                    // reload when sync flips back to false; the debouncer
                    // collapses both.
                    reloader.send()
                }
                await work.value
            }
        }
        .task {
            reloader.start {
                viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
            }
            reloader.send()
        }
        .onChange(of: holdings.count) { reloader.send() }
        .onChange(of: dividends.count) { reloader.send() }
        .onChange(of: contributions.count) { reloader.send() }
        .onChange(of: syncService.isSyncing) { _, syncing in
            if !syncing { reloader.send() }
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
    private var freedomPlanBanner: some View {
        if let settings,
           settings.hasCompletedOnboarding,
           settings.freedomPlanCompletedAt == nil {
            NavigationLink {
                GoalSettingsView(settings: settings)
            } label: {
                FreedomPlanBanner()
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var compactDashboard: some View {
        freedomPlanBanner

        if let projection = viewModel.projection {
            if let settings {
                NavigationLink {
                    GoalSettingsView(settings: settings)
                } label: {
                    IncomeGaugeMeter(projection: projection)
                }
                .buttonStyle(.plain)
            } else {
                IncomeGaugeMeter(projection: projection, isInteractive: false)
            }
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
        freedomPlanBanner

        // Row 1: KPI summary cards.
        if let summary = viewModel.summary {
            SummaryCardsRow(summary: summary, projection: viewModel.projection)
        }

        // Row 2: Hero card (gauge + action + suggestions).
        if let projection = viewModel.projection {
            if let settings {
                NavigationLink {
                    GoalSettingsView(settings: settings)
                } label: {
                    HeroCard(projection: projection, suggestions: viewModel.topSuggestions)
                }
                .buttonStyle(.plain)
            } else {
                HeroCard(projection: projection, suggestions: viewModel.topSuggestions)
            }
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
