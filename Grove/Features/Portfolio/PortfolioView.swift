import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Environment(\.horizontalSizeClass) private var sizeClass
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
                // MARK: - Top bar: toolbar OR cancel button
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
                        portfolioSelector
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                isSearching = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .fontWeight(.semibold)
                            }
                            .keyboardShortcut("f", modifiers: .command)
                            Menu {
                                Button {
                                    viewModel.showingEditPortfolio = true
                                } label: {
                                    Label("Edit Portfolio", systemImage: "pencil")
                                }
                                Button {
                                    viewModel.showingNewPortfolio = true
                                } label: {
                                    Label("New Portfolio", systemImage: "folder.badge.plus")
                                }
                                Divider()
                                Button {
                                    showingImport = true
                                } label: {
                                    Label("Import", systemImage: "square.and.arrow.down")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // MARK: - Main scrollable area
                if sizeClass == .regular && !isSearching {
                    widePortfolioLayout
                } else {
                    ScrollView {
                        if isSearching {
                            if !searchText.isEmpty {
                                searchResultsList
                            } else {
                                holdingsList
                            }
                        } else {
                            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                                portfolioHeader
                                allocationSection

                                Section {
                                    holdingsList
                                } header: {
                                    assetClassTabs
                                        .background(Color.tqBackground)
                                }
                            }
                        }
                    }
                }

                // MARK: - Bottom search bar (slides up when searching)
                if isSearching {
                    bottomSearchBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color.tqBackground)
            #if os(iOS)
            .toolbar(isSearching ? .hidden : .visible, for: .tabBar)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .animation(.easeInOut(duration: 0.18), value: isSearching)
            .navigationDestination(for: PersistentIdentifier.self) { id in
                HoldingDetailView(holdingID: id)
            }
            .sheet(isPresented: $viewModel.showingAddDetails, onDismiss: {
                if let result = viewModel.selectedSearchResult {
                    let wasAdded = holdings.contains { $0.ticker == result.symbol }
                    if wasAdded && !recentlyAdded.contains(where: { $0.symbol == result.symbol }) {
                        withAnimation { recentlyAdded.insert(result, at: 0) }
                    }
                    viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
                }
            }) {
                if let result = viewModel.selectedSearchResult {
                    AddAssetDetailSheet(searchResult: result)
                }
            }
            .sheet(isPresented: $viewModel.showingEditPortfolio) {
                if let portfolio = viewModel.selectedPortfolio {
                    EditPortfolioView(portfolio: portfolio)
                }
            }
            .sheet(isPresented: $viewModel.showingNewPortfolio) {
                NewPortfolioSheet { name in
                    viewModel.createPortfolio(name: name, modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
                }
            }
            .sheet(item: $holdingToBuy, onDismiss: { viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }) { holding in
                NewTransactionView(transactionType: .buy, preselectedHolding: holding)
            }
            .sheet(item: $holdingToSell, onDismiss: { viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }) { holding in
                NewTransactionView(transactionType: .sell, preselectedHolding: holding)
            }
            .sheet(isPresented: $showingImport, onDismiss: { viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }) {
                if let portfolio = viewModel.selectedPortfolio {
                    ImportPortfolioView(portfolio: portfolio)
                }
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
                        viewModel.deleteHolding(h, modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
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

    // MARK: - Search Results List

    private var searchResultsList: some View {
        Group {
            if debouncer.isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Searching...").foregroundStyle(.secondary)
                }
                .padding(.vertical, Theme.Spacing.sm)
            }

            if !debouncer.results.isEmpty {
                LazyVStack(spacing: 0) {
                    ForEach(debouncer.results, id: \.id) { result in
                        let added = isAlreadyAdded(result.symbol)
                        Button {
                            if !added {
                                viewModel.selectedSearchResult = result
                                viewModel.showingAddDetails = true
                            }
                        } label: {
                            searchResultRow(result: result, added: added)
                        }
                        .disabled(added)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 8)
                    }

                    Divider()
                        .padding(.horizontal, Theme.Spacing.md)
                }
            }

            if !debouncer.isSearching && debouncer.results.isEmpty && searchText.count >= 2 {
                Text("No results for \"\(searchText)\"")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Theme.Spacing.md)
            }
        }
    }

    @ViewBuilder
    private func searchResultRow(result: StockSearchResultDTO, added: Bool) -> some View {
        HStack(spacing: 12) {
            searchResultLeadingIcon(for: result, added: added)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(result.displaySymbol)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let assetClass = result.inferredAssetClass {
                        searchResultBadge(for: assetClass)
                    }
                }

                let desc = result.displayDescription
                if !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if added {
                Text("Added")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func searchResultLeadingIcon(for result: StockSearchResultDTO, added: Bool) -> some View {
        if added {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.tqAccentGreen)
                .font(.title3)
        } else if result.isCrypto {
            // Crypto-specific glyph so the row reads as a token at a glance.
            Image(systemName: "bitcoinsign.circle.fill")
                .foregroundStyle(AssetClassType.crypto.color)
                .font(.title3)
        } else {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.tqAccentGreen)
                .font(.title3)
        }
    }

    private func searchResultBadge(for assetClass: AssetClassType) -> some View {
        Text(assetClass.displayName)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(assetClass.color.opacity(0.18), in: Capsule())
            .foregroundStyle(assetClass.color)
    }

    // MARK: - Bottom Search Bar

    private var bottomSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Ticker or name", text: $searchText)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                #endif
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

    // MARK: - Wide Layout

    private var widePortfolioLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left panel: header, allocation, class tabs
            ScrollView {
                VStack(spacing: 0) {
                    portfolioHeader
                    allocationSection
                    assetClassTabs
                }
            }
            .frame(width: Theme.Layout.sidebarWidth)

            Divider()

            // Right panel: sortable holdings table
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
        }
    }

    // MARK: - Subviews

    private var portfolioSelector: some View {
        Menu {
            ForEach(viewModel.portfolios, id: \.persistentModelID) { portfolio in
                Button {
                    viewModel.selectPortfolio(portfolio, modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
                } label: {
                    HStack {
                        Text(portfolio.name)
                        if portfolio.name == viewModel.selectedPortfolio?.name {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.selectedPortfolio?.name ?? "Portfolio")
                    .font(.headline).fontWeight(.bold)
                Image(systemName: "chevron.down")
                    .font(.caption).fontWeight(.semibold)
            }
            .foregroundStyle(.primary)
        }
    }

    private var portfolioHeader: some View {
        VStack(spacing: 4) {
            Text(viewModel.totalValue.formatted())
                .font(.system(size: 32, weight: .bold, design: .rounded))
            if let summary = viewModel.summary {
                Text("Monthly income: \(summary.monthlyIncomeNet.formatted())")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
    }

    private var allocationSection: some View {
        Group {
            if !viewModel.allocationByClass.isEmpty {
                AllocationBar(allocations: viewModel.allocationByClass)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.md)
            }
        }
    }

    private var assetClassTabs: some View {
        Group {
            if sizeClass == .regular {
                // Wide: show all tabs wrapped in a flow layout
                FlowLayout(spacing: Theme.Spacing.sm) {
                    assetClassTabButtons
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
            } else {
                // Compact: horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        assetClassTabButtons
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
        }
    }

    @ViewBuilder
    private var assetClassTabButtons: some View {
        AssetClassTab(title: "All", isSelected: viewModel.selectedClass == nil, color: .tqAccentGreen) {
            viewModel.selectClass(nil, displayCurrency: displayCurrency, rates: rates)
        }
        ForEach(AssetClassType.allCases) { classType in
            let count = viewModel.holdings.filter { $0.assetClass == classType }.count
            if count > 0 {
                AssetClassTab(title: classType.displayName, isSelected: viewModel.selectedClass == classType, color: classType.color) {
                    viewModel.selectClass(classType, displayCurrency: displayCurrency, rates: rates)
                }
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
                        Button {
                            holdingToBuy = holding
                        } label: {
                            Label("Buy", systemImage: "plus.circle.fill")
                        }

                        Button {
                            holdingToSell = holding
                        } label: {
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

// MARK: - New Portfolio Sheet

struct NewPortfolioSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    let onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Portfolio Name") {
                    TextField("E.g.: Retirement, Children", text: $name)
                }
            }
            .navigationTitle("New Portfolio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { onCreate(name); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
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

    return PortfolioView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
