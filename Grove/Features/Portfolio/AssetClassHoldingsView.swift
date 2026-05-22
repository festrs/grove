import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories

/// Class-scoped holdings screen. Pushed from the portfolio root when the
/// user taps an asset-class row. Hosts the sortable holdings table for
/// this class plus the add-asset entry points.
///
/// Add routing depends on the class. Tradable classes open the global
/// `AddTickerSheet` search → `AddAssetDetailSheet`; the resulting class is
/// derived from the search result via `AssetClassType.detect` (or picked by
/// the user for custom tickers), so the screen context never lies about
/// routing. Emergency Reserve has no ticker to look up, so its add button —
/// and a `+` toolbar shortcut — skip search and open `AddAssetDetailSheet`
/// directly as a custom draft with the class pinned.
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
    @State private var showingCustomDraft = false
    @State private var pendingAdd: AddTickerSelection?
    @State private var sortOrder: [KeyPathComparator<HoldingTableRow>] = [KeyPathComparator(\HoldingTableRow.ticker)]
    @State private var isEditing = false
    @State private var selection: Set<PersistentIdentifier> = []
    @State private var showingBulkDeleteConfirm = false

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
                            message: emptyStateMessage,
                            actionTitle: addActionTitle,
                            action: { startAdd() }
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
                            isEditing: isEditing,
                            selection: $selection,
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
                            isEditing: isEditing,
                            selection: $selection,
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
        .navigationTitle(navigationTitleKey)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { exitEditMode() }
                }
            }
            if !viewModel.holdings.isEmpty, !isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
            }
            if assetClass == .emergencyReserve, !isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCustomDraft = true } label: {
                        Label("Add Reserve", systemImage: "plus")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if !viewModel.holdings.isEmpty {
                    if isEditing {
                        Button("Done") { exitEditMode() }
                    } else {
                        Button("Edit") { isEditing = true }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isEditing {
                BulkEditBar(
                    selectionCount: selection.count,
                    allSelected: allSelected,
                    currentAssetClass: assetClass,
                    onToggleSelectAll: {
                        if allSelected {
                            selection.removeAll()
                        } else {
                            selection = Set(viewModel.holdings.map(\.persistentModelID))
                        }
                    },
                    onApplyStatus: { status in
                        viewModel.applyBulkStatus(
                            status,
                            to: selection,
                            modelContext: modelContext,
                            portfolio: portfolio,
                            displayCurrency: displayCurrency,
                            rates: rates
                        )
                        selection.removeAll()
                    },
                    onApplyAssetClass: { cls in
                        viewModel.applyBulkAssetClass(
                            cls,
                            to: selection,
                            modelContext: modelContext,
                            portfolio: portfolio,
                            displayCurrency: displayCurrency,
                            rates: rates
                        )
                        selection.removeAll()
                    },
                    onDelete: {
                        showingBulkDeleteConfirm = true
                    }
                )
            }
        }
        .confirmationDialog(
            "Remove \(selection.count) holding(s)? This cannot be undone.",
            isPresented: $showingBulkDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                viewModel.applyBulkDelete(
                    ids: selection,
                    modelContext: modelContext,
                    portfolio: portfolio,
                    displayCurrency: displayCurrency,
                    rates: rates
                )
                selection.removeAll()
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingAddTicker) {
            AddTickerSheet { selection in
                pendingAdd = selection
            }
        }
        .sheet(isPresented: $showingCustomDraft, onDismiss: {
            viewModel.loadData(
                portfolio: portfolio,
                modelContext: modelContext,
                displayCurrency: displayCurrency,
                rates: rates
            )
        }) {
            AddAssetDetailSheet(customDraft: assetClass)
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
        .onChange(of: viewModel.holdings.map(\.persistentModelID)) { _, ids in
            let valid = Set(ids)
            selection = selection.intersection(valid)
            if viewModel.holdings.isEmpty {
                isEditing = false
            }
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

    private var allSelected: Bool {
        !viewModel.holdings.isEmpty && selection.count == viewModel.holdings.count
    }

    /// Nav title morphs while editing — empty selection shows "Select Items"
    /// (Apple Photos pattern), any selection shows "%lld Selected".
    /// `LocalizedStringKey` so plural rules resolve in `.xcstrings`.
    private var navigationTitleKey: LocalizedStringKey {
        if isEditing {
            return selection.isEmpty ? "Select Items" : "\(selection.count) Selected"
        }
        return LocalizedStringKey(assetClass.displayName)
    }

    private func exitEditMode() {
        selection.removeAll()
        isEditing = false
    }

    // MARK: - Add flow

    /// Emergency Reserve has no ticker to look up — its add button skips
    /// search entirely and opens the custom-draft form with the class pinned.
    /// Every other class routes through the global `AddTickerSheet` search.
    private func startAdd() {
        if assetClass == .emergencyReserve {
            showingCustomDraft = true
        } else {
            showingAddTicker = true
        }
    }

    private var emptyStateMessage: String {
        assetClass == .emergencyReserve
            ? String(localized: "Add an entry to start tracking your emergency reserve.")
            : String(localized: "Add a ticker to start tracking this class.")
    }

    private var addActionTitle: String {
        assetClass == .emergencyReserve
            ? String(localized: "Add Reserve")
            : String(localized: "Add Ticker")
    }

    // MARK: - Sort

    private enum SortOption: String, CaseIterable, Identifiable {
        case name, position, status
        var id: String { rawValue }
        var label: LocalizedStringKey {
            switch self {
            case .name: "Name"
            case .position: "Position"
            case .status: "Status"
            }
        }
        var icon: String {
            switch self {
            case .name: "textformat"
            case .position: "chart.bar.fill"
            case .status: "tag"
            }
        }
    }

    private var activeSortOption: SortOption {
        guard let key = sortOrder.first?.keyPath else { return .name }
        if key == \HoldingTableRow.allocationValue { return .position }
        if key == \HoldingTableRow.statusRank { return .status }
        return .name
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: Binding(
                get: { activeSortOption },
                set: { applySort($0) }
            )) {
                ForEach(SortOption.allCases) { option in
                    Label(option.label, systemImage: option.icon).tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.subheadline)
                .accessibilityLabel(Text("Sort"))
        }
    }

    private func applySort(_ option: SortOption) {
        switch option {
        case .name:
            sortOrder = [KeyPathComparator(\HoldingTableRow.ticker, order: .forward)]
        case .position:
            sortOrder = [KeyPathComparator(\HoldingTableRow.allocationValue, order: .reverse)]
        case .status:
            sortOrder = [KeyPathComparator(\HoldingTableRow.statusRank, order: .forward)]
        }
    }

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
