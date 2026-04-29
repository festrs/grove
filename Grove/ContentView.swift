import SwiftUI
import SwiftData
import GroveDomain

struct ContentView: View {
    let rateStore: RateStore

    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Query private var settings: [UserSettings]
    @Query private var holdings: [Holding]

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        Group {
            if settings.first?.hasCompletedOnboarding != true {
                OnboardingContainerView()
            } else {
                #if os(iOS)
                if horizontalSizeClass == .compact {
                    AppTabNavigation()
                } else {
                    AppSidebarNavigation()
                }
                #else
                AppSidebarNavigation()
                #endif
            }
        }
        .environment(\.displayCurrency, settings.first?.preferredCurrency ?? .brl)
        .overlay {
            #if DEBUG
            DebugFloatingButton()
            #endif
        }
        .task {
            ensureSettingsExist()
            await rateStore.refresh(using: backendService)
            guard settings.first?.hasCompletedOnboarding == true else { return }
            // TODO: Enable when push notifications are ready
            // await NotificationCoordinator.handleAppLaunch()
            await syncService.syncAll(
                modelContext: modelContext,
                backendService: backendService
            )
        }
        .onChange(of: settings.first?.hasCompletedOnboarding) { _, completed in
            guard completed == true else { return }
            Task {
                await syncService.syncAll(
                    modelContext: modelContext,
                    backendService: backendService
                )
            }
        }
    }

    private func ensureSettingsExist() {
        if settings.isEmpty {
            let newSettings = UserSettings()
            modelContext.insert(newSettings)
        }
    }
}

// MARK: - Navigation Item

enum AppNavigationItem: String, Hashable, CaseIterable, Identifiable {
    case dashboard
    case portfolio
    case rebalancing
    case dividendCalendar
    case incomeHistory
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: "Dashboard"
        case .portfolio: "Portfolio"
        case .rebalancing: "Invest"
        case .dividendCalendar: "Dividends"
        case .incomeHistory: "Passive Income"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "chart.pie.fill"
        case .portfolio: "briefcase.fill"
        case .rebalancing: "plus.circle.fill"
        case .dividendCalendar: "calendar"
        case .incomeHistory: "chart.bar.fill"
        case .settings: "gearshape.fill"
        }
    }
}

// MARK: - iPhone: Tab Navigation

struct AppTabNavigation: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.pie.fill") {
                DashboardView()
            }
            Tab("Portfolio", systemImage: "briefcase.fill") {
                PortfolioView()
            }
            Tab("Invest", systemImage: "plus.circle.fill") {
                RebalancingView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(.tqAccentGreen)
    }
}

// MARK: - macOS: Settings scene root

#if os(macOS)
/// Wraps `SettingsView` for the `Settings { ... }` scene so the user's
/// preferred display currency is loaded from `UserSettings` (the WindowGroup
/// can't share its environment across scenes). `\.rates` is injected at the
/// scene level by `GroveApp`.
struct SettingsSceneRoot: View {
    @Query private var settings: [UserSettings]

    var body: some View {
        MacSettingsView()
            .environment(\.displayCurrency, settings.first?.preferredCurrency ?? .brl)
    }
}
#endif

// MARK: - iPad / Mac: Sidebar Navigation

struct AppSidebarNavigation: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @State private var selection: AppNavigationItem? = .dashboard
    #if os(macOS)
    @State private var showingAddHolding = false
    #endif

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Overview") {
                    sidebarLink(.dashboard)
                    sidebarLink(.portfolio)
                }

                Section("Investments") {
                    sidebarLink(.rebalancing)
                }

                Section("Income") {
                    sidebarLink(.dividendCalendar)
                    sidebarLink(.incomeHistory)
                }

                #if !os(macOS)
                // iPadOS has no app-menu Settings, so keep it in the sidebar.
                // On macOS, Settings lives in the standard ⌘, Settings scene.
                Section {
                    sidebarLink(.settings)
                }
                #endif
            }
            .navigationTitle("Grove")
            .listStyle(.sidebar)
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
            #endif
        } detail: {
            NavigationStack {
                switch selection {
                case .dashboard:
                    DashboardView()
                case .portfolio:
                    PortfolioView()
                case .rebalancing:
                    RebalancingView()
                case .dividendCalendar:
                    DividendCalendarView()
                case .incomeHistory:
                    IncomeHistoryView()
                case .settings:
                    #if os(macOS)
                    DashboardView()
                    #else
                    SettingsView()
                    #endif
                case nil:
                    DashboardView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.tqAccentGreen)
        #if os(macOS)
        // No window-level "+" toolbar button — the Portfolio screen exposes
        // search inline via `.searchable`. ⌘N still opens the dedicated
        // MacAddHoldingSheet from anywhere via the CommandGroup in GroveApp.
        .sheet(isPresented: $showingAddHolding) {
            MacAddHoldingSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAddHolding)) { _ in
            showingAddHolding = true
        }
        #endif
    }

    private func sidebarLink(_ item: AppNavigationItem) -> some View {
        Label(item.label, systemImage: item.icon)
            .tag(item)
    }
}

// MARK: - macOS: Add Holding sheet (toolbar + ⌘N)

#if os(macOS)
struct MacAddHoldingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.backendService) private var backendService

    @State private var query = ""
    @State private var debouncer = SearchDebouncer()
    @State private var selectedResult: StockSearchResultDTO?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search ticker or name (e.g. ITUB3, AAPL)", text: $query)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                }
                .padding(10)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .padding()

                if debouncer.isSearching {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Searching…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                List(debouncer.results) { result in
                    Button {
                        selectedResult = result
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.tqAccentGreen)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.displaySymbol).font(.headline)
                                if let name = result.name, !name.isEmpty {
                                    Text(name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)

                if !debouncer.isSearching && debouncer.results.isEmpty && query.count >= 2 {
                    Text("No results for \"\(query)\"")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .frame(minWidth: 520, minHeight: 420)
            .navigationTitle("Add Holding")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: query) { _, newValue in
                debouncer.send(newValue)
            }
            .task {
                let svc = backendService
                debouncer.start { q in
                    (try? await svc.searchStocks(query: q)) ?? []
                }
            }
            .sheet(item: $selectedResult, onDismiss: { dismiss() }) { result in
                AddAssetDetailSheet(searchResult: result)
            }
        }
    }
}
#endif

#Preview {
    ContentView(rateStore: RateStore())
        .modelContainer(for: [
            Portfolio.self,
            Holding.self,
            DividendPayment.self,
            Contribution.self,
            UserSettings.self,
        ], inMemory: true)
}
