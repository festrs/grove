#if os(iOS)
import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories

/// iPhone portfolio screen — class-first hierarchy.
///
/// Root: portfolio total + allocation bar + class table. Tapping a class
/// row pushes `AssetClassHoldingsView` (the only place new holdings can be
/// added — search lives there now, scoped to the chosen class). The
/// previous flat list + bottom-drawer search and `AssetClassTabsRow` are
/// gone.
struct CompactPortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query private var holdings: [Holding]
    @State private var viewModel = PortfolioViewModel()
    @State private var showingImport = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    topBar
                    PortfolioTotalHeader(
                        totalValue: viewModel.totalValue,
                        monthlyIncomeNet: viewModel.summary?.monthlyIncomeNet
                    )
                    if !viewModel.allocationByClass.isEmpty {
                        AllocationBar(allocations: viewModel.allocationByClass)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.bottom, Theme.Spacing.md)
                    }

                    if viewModel.allocationByClass.isEmpty {
                        emptyState
                    } else {
                        PortfolioClassTable(
                            allocations: viewModel.allocationByClass,
                            holdings: viewModel.holdings,
                            onSelect: { classType in
                                navigationPath.append(classType)
                            }
                        )
                        .background(Color.tqCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                        .padding(.horizontal, Theme.Spacing.md)
                    }

                    Color.clear.frame(height: Theme.Spacing.lg)
                }
            }
            .background(Color.tqBackground)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AssetClassType.self) { classType in
                AssetClassHoldingsView(
                    assetClass: classType,
                    portfolio: viewModel.selectedPortfolio,
                    path: $navigationPath
                )
            }
            .navigationDestination(for: PersistentIdentifier.self) { id in
                HoldingDetailView(holdingID: id)
            }
            .modifier(PortfolioSheetsAndAlerts(
                viewModel: viewModel,
                showingImport: $showingImport,
                holdings: holdings
            ))
            .refreshable {
                await syncService.syncAll(modelContext: modelContext, backendService: backendService)
                viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
            }
            .task {
                viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
            }
            .onChange(of: syncService.isSyncing) { _, syncing in
                if !syncing { viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }
            }
            .onChange(of: holdings.count) {
                viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
            }
        }
    }

    // MARK: - Top bar

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

    private var emptyState: some View {
        TQEmptyState(
            icon: "briefcase",
            title: "No Assets",
            message: "Tap a class to add tickers, or open Settings → Allocation to set targets."
        )
        .padding(.top, 60)
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
