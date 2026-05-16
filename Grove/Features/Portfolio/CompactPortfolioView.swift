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
    @State private var showingAddTicker = false
    @State private var pendingAdd: AddTickerSelection?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    PortfolioTotalHeader(
                        totalValue: viewModel.totalValue,
                        monthlyIncomeNet: viewModel.summary?.monthlyIncomeNet,
                        isLoading: viewModel.isLoading && viewModel.summary == nil
                    )

                    if viewModel.isLoading && viewModel.summary == nil {
                        ProgressView()
                            .padding(.top, 40)
                    } else if viewModel.allocationByClass.isEmpty {
                        emptyState
                    } else {
                        AllocationBar(allocations: viewModel.allocationByClass)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.bottom, Theme.Spacing.md)

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
            .navigationTitle(Text(verbatim: viewModel.portfolio?.name ?? String(localized: "Portfolio")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.showingEditPortfolio = true
                    } label: {
                        Label("Rename Portfolio", systemImage: "pencil")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTicker = true
                    } label: {
                        Label("Add Ticker", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImport = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationDestination(for: AssetClassType.self) { classType in
                AssetClassHoldingsView(
                    assetClass: classType,
                    portfolio: viewModel.portfolio,
                    path: $navigationPath
                )
            }
            .navigationDestination(for: PersistentIdentifier.self) { id in
                HoldingDetailView(holdingID: id)
            }
            .modifier(PortfolioSheetsAndAlerts(
                viewModel: viewModel,
                showingImport: $showingImport,
                showingAddTicker: $showingAddTicker,
                pendingAdd: $pendingAdd,
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

    private var emptyState: some View {
        TQEmptyState(
            icon: "briefcase",
            title: "No assets yet",
            message: "Tap a class to add your first ticker. Grove will rank your monthly Aportar list as soon as one is marked Invest."
        )
        .padding(.top, 60)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Portfolio.self, Holding.self, DividendPayment.self, GroveDomain.Transaction.self, UserSettings.self,
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
