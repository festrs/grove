import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories

/// iPad + macOS portfolio screen — class-first hierarchy via
/// `NavigationSplitView`. Sidebar shows the portfolio total + allocation
/// bar + class table; the detail column hosts `AssetClassHoldingsView`
/// for the selected class. Pushing into a holding stays inside the detail
/// column's `NavigationStack`.
struct WidePortfolioView: View {
    /// When set, the view scopes itself to this portfolio on first appear.
    /// Used by `PortfoliosOverviewView` to drill into a specific portfolio.
    var initialPortfolioID: PersistentIdentifier? = nil

    /// When set, a back button is shown in the sidebar that returns to the
    /// portfolios overview. Nil = no back button (standalone or single-
    /// portfolio mode).
    var onBackToOverview: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query private var holdings: [Holding]
    @State private var viewModel = PortfolioViewModel()
    @State private var selectedClass: AssetClassType?
    @State private var showingImport = false
    @State private var detailPath = NavigationPath()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 360)

            Divider()

            NavigationStack(path: $detailPath) {
                Group {
                    if let assetClass = selectedClass {
                        AssetClassHoldingsView(
                            assetClass: assetClass,
                            portfolio: viewModel.selectedPortfolio,
                            path: $detailPath
                        )
                        .id(assetClass)
                    } else {
                        TQEmptyState(
                            icon: "rectangle.stack",
                            title: "Pick an asset class",
                            message: "Select a class on the left to see its holdings."
                        )
                    }
                }
                .navigationDestination(for: PersistentIdentifier.self) { id in
                    HoldingDetailView(holdingID: id)
                }
            }
            .frame(maxWidth: .infinity)
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
            if let id = initialPortfolioID,
               viewModel.selectedPortfolio?.persistentModelID != id,
               let target = viewModel.portfolios.first(where: { $0.persistentModelID == id }) {
                viewModel.selectPortfolio(target, modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
            }
            if selectedClass == nil {
                selectedClass = viewModel.allocationByClass.first?.assetClass
            }
        }
        .onChange(of: syncService.isSyncing) { _, syncing in
            if !syncing { viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }
        }
        .onChange(of: holdings.count) {
            viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(spacing: 0) {
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
                    TQEmptyState(
                        icon: "briefcase",
                        title: "No Assets",
                        message: "Tap a class to add tickers, or open Settings → Allocation to set targets."
                    )
                    .padding(.top, 40)
                } else {
                    PortfolioClassTable(
                        allocations: viewModel.allocationByClass,
                        holdings: viewModel.holdings,
                        onSelect: { classType in
                            // Detail column re-renders fresh when class
                            // changes (see `.id(assetClass)`).
                            detailPath = NavigationPath()
                            selectedClass = classType
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
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }

    private var topBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let onBack = onBackToOverview {
                Button {
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Portfolios")
                            .font(.subheadline)
                    }
                    .foregroundStyle(Color.tqAccentGreen)
                }
                .buttonStyle(.plain)
            }
            if let name = viewModel.selectedPortfolio?.name {
                Text(name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer()
            PortfolioOverflowMenu(
                onEdit: { viewModel.showingEditPortfolio = true },
                onNew: onBackToOverview == nil
                    ? { viewModel.showingNewPortfolio = true }
                    : nil,
                onImport: { showingImport = true }
            )
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
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
