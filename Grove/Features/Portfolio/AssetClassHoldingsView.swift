import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories

/// Class-scoped holdings screen. Pushed from the portfolio root when the
/// user taps an asset-class row. Hosts the sortable holdings table for
/// this class plus a `+` toolbar shortcut that opens the global add-ticker
/// flow (`AddTickerSheet` → `AddAssetDetailSheet`). Adds aren't scoped to
/// the screen's class — the resulting class is derived from the search
/// result via `AssetClassType.detect` (or chosen by the user for custom
/// tickers), so the screen context never lies about routing.
struct AssetClassHoldingsView: View {
    let assetClass: AssetClassType
    let portfolio: Portfolio?
    @Binding var path: NavigationPath

    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @Query private var holdings: [Holding]

    @State private var viewModel: AssetClassHoldingsViewModel
    @State private var showingAddTicker = false
    @State private var pendingAdd: AddTickerSelection?
    @State private var sortOrder: [KeyPathComparator<HoldingTableRow>] = [KeyPathComparator(\HoldingTableRow.ticker)]

    init(
        assetClass: AssetClassType,
        portfolio: Portfolio? = nil,
        path: Binding<NavigationPath>
    ) {
        self.assetClass = assetClass
        self.portfolio = portfolio
        _path = path
        _viewModel = State(initialValue: AssetClassHoldingsViewModel(assetClass: assetClass))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.xs, pinnedViews: [.sectionHeaders]) {
                classHeader

                Section {
                    if viewModel.holdings.isEmpty {
                        TQEmptyState(
                            icon: assetClass.icon,
                            title: "No \(assetClass.displayName) yet",
                            message: "Tap + above to search for a ticker or add a custom one.",
                            actionTitle: "Add Ticker",
                            action: { showingAddTicker = true }
                        )
                        .padding(.top, 60)
                    } else if useCardLayout {
                        HoldingCardsView(
                            holdings: viewModel.holdings,
                            totalValue: viewModel.classTotalValue,
                            onSelect: { id in path.append(id) },
                            onChangeStatus: { holding, status in
                                holding.status = status
                            },
                            onBuy: { viewModel.holdingToBuy = $0 },
                            onSell: { viewModel.holdingToSell = $0 },
                            onRemove: { viewModel.holdingToRemove = $0 },
                            sortOrder: $sortOrder
                        )
                    } else {
                        HoldingsListView(
                            holdings: viewModel.holdings,
                            totalValue: viewModel.classTotalValue,
                            onSelect: { id in path.append(id) },
                            onChangeStatus: { holding, status in
                                holding.status = status
                            },
                            onBuy: { viewModel.holdingToBuy = $0 },
                            onSell: { viewModel.holdingToSell = $0 },
                            onRemove: { viewModel.holdingToRemove = $0 },
                            sortOrder: $sortOrder
                        )
                    }
                } header: {
                    if !viewModel.holdings.isEmpty, !useCardLayout {
                        HoldingsColumnHeader(sortOrder: $sortOrder)
                            .background(Color.tqBackground)
                    }
                }
            }
        }
        .background(Color.tqBackground)
        .navigationTitle(assetClass.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTicker = true
                } label: {
                    Label("Add Ticker", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTicker) {
            AddTickerSheet { selection in
                pendingAdd = selection
            }
        }
        .sheet(item: $pendingAdd, onDismiss: {
            viewModel.loadData(
                portfolio: portfolio,
                modelContext: modelContext,
                displayCurrency: displayCurrency,
                rates: rates
            )
        }) { selection in
            switch selection {
            case .found(let result):
                AddAssetDetailSheet(searchResult: result, assetClass: nil)
            case .custom(let symbol):
                AddAssetDetailSheet(customSymbol: symbol)
            }
        }
        .sheet(item: $viewModel.holdingToBuy, onDismiss: {
            viewModel.loadData(
                portfolio: portfolio,
                modelContext: modelContext,
                displayCurrency: displayCurrency,
                rates: rates
            )
        }) { holding in
            NewTransactionView(transactionType: .buy, preselectedHolding: holding)
        }
        .sheet(item: $viewModel.holdingToSell, onDismiss: {
            viewModel.loadData(
                portfolio: portfolio,
                modelContext: modelContext,
                displayCurrency: displayCurrency,
                rates: rates
            )
        }) { holding in
            NewTransactionView(transactionType: .sell, preselectedHolding: holding)
        }
        .alert(
            "Remove Asset",
            isPresented: Binding(
                get: { viewModel.holdingToRemove != nil },
                set: { if !$0 { viewModel.holdingToRemove = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { viewModel.holdingToRemove = nil }
            Button("Remove", role: .destructive) {
                if let h = viewModel.holdingToRemove {
                    viewModel.deleteHolding(
                        h,
                        modelContext: modelContext,
                        portfolio: portfolio,
                        displayCurrency: displayCurrency,
                        rates: rates
                    )
                    viewModel.holdingToRemove = nil
                }
            }
        } message: {
            if let h = viewModel.holdingToRemove {
                if h.transactions.isEmpty {
                    Text("Remove \(h.ticker) from portfolio?")
                } else {
                    Text("Remove \(h.ticker) from portfolio? All \(h.transactions.count) transaction(s) will also be deleted. This action cannot be undone.")
                }
            }
        }
        .task(id: holdings.count) {
            viewModel.loadData(
                portfolio: portfolio,
                modelContext: modelContext,
                displayCurrency: displayCurrency,
                rates: rates
            )
        }
        .onChange(of: syncService.isSyncing) { _, syncing in
            if !syncing {
                viewModel.loadData(
                    portfolio: portfolio,
                    modelContext: modelContext,
                    displayCurrency: displayCurrency,
                    rates: rates
                )
            }
        }
        .refreshable {
            await syncService.syncAll(modelContext: modelContext, backendService: backendService)
            viewModel.loadData(
                portfolio: portfolio,
                modelContext: modelContext,
                displayCurrency: displayCurrency,
                rates: rates
            )
        }
    }

    // MARK: - Pieces

    private var useCardLayout: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    private var classHeader: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(assetClass.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: assetClass.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(assetClass.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(assetClass.displayName)
                        .font(.title3.weight(.bold))
                    Text(viewModel.classTotalValue.formatted())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                if viewModel.classTargetPercent > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(viewModel.classCurrentPercent.formattedPercent(decimals: 0))
                            .font(.system(.body, weight: .semibold))
                            .monospacedDigit()
                        Text("of \(viewModel.classTargetPercent.formattedPercent(decimals: 0)) target")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(Color.tqCardBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
        }
    }

}
