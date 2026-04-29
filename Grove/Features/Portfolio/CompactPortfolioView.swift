#if os(iOS)
import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories

/// iPhone portfolio screen. Uses the bottom-drawer search pattern (custom
/// magnifying-glass button → animated drawer + search field at the bottom).
/// macOS + iPad use `WidePortfolioView` with the native `.searchable`.
struct CompactPortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query private var holdings: [Holding]
    @State private var viewModel = PortfolioViewModel()
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var debouncer = SearchDebouncer()
    @State private var recentlyAdded: [StockSearchResultDTO] = []
    @State private var holdingToBuy: Holding?
    @State private var holdingToSell: Holding?
    @State private var showingImport = false
    @State private var navigationPath = NavigationPath()
    @FocusState private var searchFocused: Bool

    private func isAlreadyAdded(_ symbol: String) -> Bool {
        recentlyAdded.contains { $0.symbol == symbol }
            || viewModel.holdings.contains { $0.ticker == symbol }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                topBar

                if isSearching {
                    ScrollView {
                        if !searchText.isEmpty {
                            PortfolioSearchResultsList(
                                results: debouncer.results,
                                isSearching: debouncer.isSearching,
                                searchText: searchText,
                                isAlreadyAdded: isAlreadyAdded,
                                onAdd: handleAdd
                            )
                        } else {
                            holdingsList
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                            PortfolioTotalHeader(
                                totalValue: viewModel.totalValue,
                                monthlyIncomeNet: viewModel.summary?.monthlyIncomeNet
                            )
                            allocationSection
                            Section {
                                holdingsList
                            } header: {
                                AssetClassTabsRow(
                                    holdings: viewModel.holdings,
                                    selected: viewModel.selectedClass,
                                    isWide: false,
                                    onSelect: { viewModel.selectClass($0, displayCurrency: displayCurrency, rates: rates) }
                                )
                                .background(Color.tqBackground)
                            }
                        }
                    }
                }

                if isSearching {
                    bottomSearchBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color.tqBackground)
            .toolbar(isSearching ? .hidden : .visible, for: .tabBar)
            .toolbar(.hidden, for: .navigationBar)
            .animation(.easeInOut(duration: 0.18), value: isSearching)
            .navigationDestination(for: PersistentIdentifier.self) { id in
                HoldingDetailView(holdingID: id)
            }
            .modifier(PortfolioSheetsAndAlerts(
                viewModel: viewModel,
                holdingToBuy: $holdingToBuy,
                holdingToSell: $holdingToSell,
                showingImport: $showingImport,
                recentlyAdded: $recentlyAdded,
                holdings: holdings
            ))
            .refreshable {
                await syncService.syncAll(modelContext: modelContext, backendService: backendService)
                viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
            }
            .task {
                viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
                let service = backendService
                debouncer.start { query in
                    (try? await service.searchStocks(query: query)) ?? []
                }
            }
            .onChange(of: syncService.isSyncing) { _, syncing in
                if !syncing { viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }
            }
            .onChange(of: holdings.count) {
                guard !isSearching else { return }
                viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
            }
            .onChange(of: searchText) { _, newValue in
                debouncer.send(newValue)
            }
            .onChange(of: isSearching) { _, searching in
                if searching {
                    DispatchQueue.main.async { searchFocused = true }
                } else {
                    searchFocused = false
                }
            }
        }
    }

    // MARK: - Top bar

    @ViewBuilder
    private var topBar: some View {
        if isSearching {
            HStack {
                Spacer()
                Button("OK") { closeSearch() }
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .transition(.move(edge: .top).combined(with: .opacity))
        } else {
            HStack {
                PortfolioSelectorMenu(
                    portfolios: viewModel.portfolios,
                    selected: viewModel.selectedPortfolio,
                    onSelect: { viewModel.selectPortfolio($0, modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }
                )
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        isSearching = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .fontWeight(.semibold)
                    }
                    .keyboardShortcut("f", modifiers: .command)

                    PortfolioOverflowMenu(
                        onEdit: { viewModel.showingEditPortfolio = true },
                        onNew: { viewModel.showingNewPortfolio = true },
                        onImport: { showingImport = true }
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Search drawer

    private var bottomSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Ticker or name", text: $searchText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    debouncer.results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.tqCardBackground, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private func closeSearch() {
        searchFocused = false
        searchText = ""
        debouncer.results = []
        recentlyAdded = []
        withAnimation { isSearching = false }
    }

    private func handleAdd(_ result: StockSearchResultDTO) {
        let ok = viewModel.addStudyHolding(
            from: result,
            modelContext: modelContext,
            backendService: backendService
        )
        if ok, !recentlyAdded.contains(where: { $0.symbol == result.symbol }) {
            withAnimation { recentlyAdded.insert(result, at: 0) }
        }
        viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
    }

    // MARK: - Allocation + holdings

    private var allocationSection: some View {
        Group {
            if !viewModel.allocationByClass.isEmpty {
                AllocationBar(allocations: viewModel.allocationByClass)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.md)
            }
        }
    }

    private var holdingsList: some View {
        LazyVStack(spacing: 0) {
            if viewModel.filteredHoldings.isEmpty && !isSearching {
                TQEmptyState(
                    icon: "briefcase",
                    title: "No Assets",
                    message: "Search for a ticker to add your first asset.",
                    actionTitle: "Search",
                    action: { withAnimation { isSearching = true } }
                )
                .padding(.top, 60)
            } else {
                ForEach(viewModel.filteredHoldings, id: \.persistentModelID) { holding in
                    NavigationLink(value: holding.persistentModelID) {
                        HoldingRow(holding: holding, totalValue: viewModel.totalValue)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.holdingToRemove = holding
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button { holdingToBuy = holding } label: {
                            Label("Buy", systemImage: "plus.circle.fill")
                        }
                        Button { holdingToSell = holding } label: {
                            Label("Sell", systemImage: "minus.circle.fill")
                        }
                        Divider()
                        Menu("Status") {
                            ForEach(HoldingStatus.allCases) { status in
                                Button {
                                    holding.status = status
                                } label: {
                                    Label(status.displayName, systemImage: status.icon)
                                }
                                .disabled(holding.status == status)
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            viewModel.holdingToRemove = holding
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self,
        configurations: config
    )
    let ctx = container.mainContext

    let portfolio = Portfolio(name: "Meu Portfolio")
    ctx.insert(portfolio)

    let settings = UserSettings(hasCompletedOnboarding: true)
    settings.classAllocations = [
        .acoesBR: 25, .fiis: 25, .usStocks: 20,
        .reits: 10, .crypto: 10, .rendaFixa: 10
    ]
    ctx.insert(settings)

    for h in [.itub3, .wege3, .btlg11, .knri11, .aapl, .vti, .o, .btc, .ipca2035] as [Holding] {
        h.portfolio = portfolio
        ctx.insert(h)
    }

    return CompactPortfolioView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
#endif
