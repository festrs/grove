import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories

/// Class-scoped holdings screen. Pushed from the portfolio root when the
/// user taps an asset-class row. Hosts the sortable holdings table for
/// this class plus the "Add to <Class>" entry point — the only place new
/// holdings can be added in the new hierarchy.
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
    @State private var showingAddSheet = false
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
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                classHeader

                Section {
                    if viewModel.holdings.isEmpty {
                        TQEmptyState(
                            icon: assetClass.icon,
                            title: "No \(assetClass.displayName) yet",
                            message: "Tap Add to search for a ticker or create a custom one.",
                            actionTitle: "Add to \(assetClass.displayName)",
                            action: { showingAddSheet = true }
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
        .safeAreaInset(edge: .bottom) {
            addButton
        }
        .background(Color.tqBackground)
        .navigationTitle(assetClass.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingAddSheet) {
            AddToClassSheet(
                viewModel: viewModel,
                onSelectResult: { result in
                    viewModel.selectedSearchResult = result
                    viewModel.showingAddDetails = true
                }
            )
        }
        .sheet(isPresented: $viewModel.showingAddDetails, onDismiss: {
            viewModel.loadData(
                portfolio: portfolio,
                modelContext: modelContext,
                displayCurrency: displayCurrency,
                rates: rates
            )
        }) {
            if let result = viewModel.selectedSearchResult {
                // Pass nil so AddAssetDetailSheet auto-detects the class
                // from the result. Search returns assets from every class
                // (so custom-add and cross-class discovery still work),
                // and forcing the screen's class here would mis-file e.g.
                // AAPL as Ações BR when picked from the BR screen.
                AddAssetDetailSheet(searchResult: result, assetClass: nil)
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
                if h.contributions.isEmpty {
                    Text("Remove \(h.ticker) from portfolio?")
                } else {
                    Text("Remove \(h.ticker) from portfolio? All \(h.contributions.count) transaction(s) will also be deleted. This action cannot be undone.")
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

    private var addButton: some View {
        Button {
            showingAddSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .fontWeight(.bold)
                Text("Add to \(assetClass.displayName)")
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 14)
            .background(assetClass.color, in: Capsule())
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.bottom, Theme.Spacing.md)
    }
}
