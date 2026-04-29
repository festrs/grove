import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories

/// iPad + macOS portfolio screen. Uses the system `.searchable` toolbar
/// field for stock lookup and a vertical wide layout (header + ring + tabs
/// on top, sortable holdings table on bottom). iPhone uses
/// `CompactPortfolioView`.
struct WidePortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query private var holdings: [Holding]
    @State private var viewModel = PortfolioViewModel()
    @State private var searchText = ""
    @State private var debouncer = SearchDebouncer()
    @State private var recentlyAdded: [StockSearchResultDTO] = []
    @State private var holdingToBuy: Holding?
    @State private var holdingToSell: Holding?
    @State private var showingImport = false
    @State private var navigationPath = NavigationPath()

    private var showingSearchResults: Bool {
        !searchText.isEmpty
    }

    private func isAlreadyAdded(_ symbol: String) -> Bool {
        recentlyAdded.contains { $0.symbol == symbol }
            || viewModel.holdings.contains { $0.ticker == symbol }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                topBar

                if showingSearchResults {
                    ScrollView {
                        PortfolioSearchResultsList(
                            results: debouncer.results,
                            isSearching: debouncer.isSearching,
                            searchText: searchText,
                            isAlreadyAdded: isAlreadyAdded,
                            onAdd: handleAdd
                        )
                    }
                } else {
                    wideLayout
                }
            }
            .background(Color.tqBackground)
            .searchable(text: $searchText, placement: .toolbar, prompt: Text("Search stocks"))
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
                viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
            }
            .onChange(of: searchText) { _, newValue in
                debouncer.send(newValue)
            }
        }
    }

    // MARK: - Top bar (portfolio selector + overflow menu)

    private var topBar: some View {
        HStack {
            PortfolioSelectorMenu(
                portfolios: viewModel.portfolios,
                selected: viewModel.selectedPortfolio,
                onSelect: { viewModel.selectPortfolio($0, modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }
            )
            Spacer()
            PortfolioOverflowMenu(
                onEdit: { viewModel.showingEditPortfolio = true },
                onNew: { viewModel.showingNewPortfolio = true },
                onImport: { showingImport = true }
            )
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Wide layout (header + ring + tabs / sortable table)

    private var wideLayout: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                PortfolioTotalHeader(
                    totalValue: viewModel.totalValue,
                    monthlyIncomeNet: viewModel.summary?.monthlyIncomeNet
                )
                allocationSection
                AssetClassTabsRow(
                    holdings: viewModel.holdings,
                    selected: viewModel.selectedClass,
                    isWide: true,
                    onSelect: { viewModel.selectClass($0, displayCurrency: displayCurrency, rates: rates) }
                )
            }
            .frame(maxWidth: .infinity)

            Divider()

            HoldingsTableView(
                holdings: viewModel.filteredHoldings,
                totalValue: viewModel.totalValue,
                onSelect: { id in
                    navigationPath.append(id)
                },
                onChangeStatus: { holding, status in
                    holding.status = status
                },
                onBuy: { holding in
                    holdingToBuy = holding
                },
                onSell: { holding in
                    holdingToSell = holding
                },
                onRemove: { holding in
                    viewModel.holdingToRemove = holding
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var allocationSection: some View {
        Group {
            if !viewModel.allocationByClass.isEmpty {
                HStack {
                    Spacer()
                    AllocationBar(allocations: viewModel.allocationByClass)
                        .frame(maxWidth: 520)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
            }
        }
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

    return WidePortfolioView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
