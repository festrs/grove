import SwiftUI
import SwiftData

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Environment(\.horizontalSizeClass) private var sizeClass
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
                            Button { withAnimation { isSearching = true } } label: {
                                Image(systemName: "magnifyingglass")
                                    .fontWeight(.semibold)
                            }
                            .keyboardShortcut("f", modifiers: .command)
                            Menu {
                                Button {
                                    viewModel.showingEditPortfolio = true
                                } label: {
                                    Label("Editar portfolio", systemImage: "pencil")
                                }
                                Button {
                                    viewModel.showingNewPortfolio = true
                                } label: {
                                    Label("Novo portfolio", systemImage: "folder.badge.plus")
                                }
                                Divider()
                                Button {
                                    showingImport = true
                                } label: {
                                    Label("Importar", systemImage: "square.and.arrow.down")
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
            .animation(.easeInOut(duration: 0.3), value: isSearching)
            .navigationDestination(for: PersistentIdentifier.self) { id in
                HoldingDetailView(holdingID: id)
            }
            .sheet(isPresented: $viewModel.showingAddDetails, onDismiss: {
                if let result = viewModel.selectedSearchResult {
                    let wasAdded = holdings.contains { $0.ticker == result.symbol }
                    if wasAdded && !recentlyAdded.contains(where: { $0.symbol == result.symbol }) {
                        withAnimation { recentlyAdded.insert(result, at: 0) }
                    }
                    viewModel.loadData(modelContext: modelContext)
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
                    viewModel.createPortfolio(name: name, modelContext: modelContext)
                }
            }
            .sheet(item: $holdingToBuy, onDismiss: { viewModel.loadData(modelContext: modelContext) }) { holding in
                NewTransactionView(transactionType: .buy, preselectedHolding: holding)
            }
            .sheet(item: $holdingToSell, onDismiss: { viewModel.loadData(modelContext: modelContext) }) { holding in
                NewTransactionView(transactionType: .sell, preselectedHolding: holding)
            }
            .sheet(isPresented: $showingImport, onDismiss: { viewModel.loadData(modelContext: modelContext) }) {
                if let portfolio = viewModel.selectedPortfolio {
                    ImportPortfolioView(portfolio: portfolio)
                }
            }
            .alert(
                "Remover ativo",
                isPresented: Binding(
                    get: { viewModel.holdingToRemove != nil },
                    set: { if !$0 { viewModel.holdingToRemove = nil } }
                )
            ) {
                Button("Cancelar", role: .cancel) { viewModel.holdingToRemove = nil }
                Button("Remover", role: .destructive) {
                    if let h = viewModel.holdingToRemove {
                        viewModel.deleteHolding(h, modelContext: modelContext)
                        viewModel.holdingToRemove = nil
                    }
                }
            } message: {
                if let h = viewModel.holdingToRemove {
                    Text("Remover \(h.ticker) do portfolio?")
                }
            }
            .refreshable {
                await syncService.syncAll(modelContext: modelContext, backendService: backendService)
                viewModel.loadData(modelContext: modelContext)
            }
            .task {
                viewModel.loadData(modelContext: modelContext)
                let service = backendService
                debouncer.start { query in
                    (try? await service.searchStocks(query: query)) ?? []
                }
            }
            .onChange(of: syncService.isSyncing) { _, syncing in
                if !syncing { viewModel.loadData(modelContext: modelContext) }
            }
            .onChange(of: holdings.count) {
                viewModel.loadData(modelContext: modelContext)
            }
            .onChange(of: searchText) { _, newValue in
                debouncer.send(newValue)
            }
            .onChange(of: isSearching) { _, searching in
                if searching { searchFocused = true }
            }
        }
    }

    // MARK: - Search Results List

    private var searchResultsList: some View {
        Group {
            if debouncer.isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Buscando...").foregroundStyle(.secondary)
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
                            HStack(spacing: 12) {
                                Image(systemName: added ? "checkmark.circle.fill" : "plus.circle.fill")
                                    .foregroundStyle(added ? Color.tqAccentGreen : Color.tqAccentGreen)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.displaySymbol)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
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
                                    Text("Adicionado")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
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
                Text("Nenhum resultado para \"\(searchText)\"")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Theme.Spacing.md)
            }
        }
    }

    // MARK: - Bottom Search Bar

    private var bottomSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Ticker ou nome", text: $searchText)
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
                totalValue: viewModel.totalValueBRL,
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
                    viewModel.selectPortfolio(portfolio, modelContext: modelContext)
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
            Text(viewModel.totalValueBRL.formattedBRL())
                .font(.system(size: 32, weight: .bold, design: .rounded))
            if let summary = viewModel.summary {
                Text("Renda mensal: \(summary.monthlyIncomeNet.formattedBRL())")
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
        AssetClassTab(title: "Todos", isSelected: viewModel.selectedClass == nil, color: .tqAccentGreen) {
            viewModel.selectClass(nil)
        }
        ForEach(AssetClassType.allCases) { classType in
            let count = viewModel.holdings.filter { $0.assetClass == classType }.count
            if count > 0 {
                AssetClassTab(title: classType.displayName, isSelected: viewModel.selectedClass == classType, color: classType.color) {
                    viewModel.selectClass(classType)
                }
            }
        }
    }

    private var holdingsList: some View {
        LazyVStack(spacing: 0) {
            if viewModel.filteredHoldings.isEmpty && !isSearching {
                TQEmptyState(
                    icon: "briefcase",
                    title: "Nenhum ativo",
                    message: "Busque um ticker para adicionar seu primeiro ativo.",
                    actionTitle: "Buscar",
                    action: { withAnimation { isSearching = true } }
                )
                .padding(.top, 60)
            } else {
                ForEach(viewModel.filteredHoldings, id: \.persistentModelID) { holding in
                    NavigationLink(value: holding.persistentModelID) {
                        HoldingRow(holding: holding, totalValue: viewModel.totalValueBRL)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            holdingToBuy = holding
                        } label: {
                            Label("Comprar", systemImage: "plus.circle.fill")
                        }

                        Button {
                            holdingToSell = holding
                        } label: {
                            Label("Vender", systemImage: "minus.circle.fill")
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
                            Label("Remover", systemImage: "trash")
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
                Section("Nome do portfolio") {
                    TextField("Ex: Aposentadoria, Filhos", text: $name)
                }
            }
            .navigationTitle("Novo portfolio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Criar") { onCreate(name); dismiss() }
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
