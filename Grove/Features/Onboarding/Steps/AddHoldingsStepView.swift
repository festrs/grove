import SwiftUI

struct AddHoldingsStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.backendService) private var backendService

    @State private var selectedTab = 0
    @State private var debouncer = SearchDebouncer()
    @State private var importViewModel = ImportViewModel()

    private var isSearching: Bool {
        !viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // MARK: - Header
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Adicione seus ativos")
                    .font(.system(size: Theme.FontSize.title2, weight: .bold))

                Text("Adicione os tickers que voce ja possui ou quer acompanhar. Transacoes serao registradas depois.")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Color.tqSecondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)

            // MARK: - Tab Picker
            Picker("Modo", selection: $selectedTab) {
                Text("Buscar").tag(0)
                Text("Importar").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.lg)

            if selectedTab == 0 {
                searchTab
            } else {
                ImportView(
                    viewModel: importViewModel,
                    showFileOption: true,
                    existingTickers: Set(viewModel.pendingHoldings.map { $0.ticker.uppercased() }),
                    confirmLabel: "Adicionar"
                ) { positions in
                    withAnimation {
                        viewModel.addHoldings(from: positions)
                    }
                }
            }
        }
    }

    // MARK: - Search Tab

    private var searchTab: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.xs) {
                // Search results (when actively searching)
                if viewModel.isSearching {
                    ProgressView()
                        .padding(.vertical, Theme.Spacing.md)
                } else if isSearching {
                    ForEach(viewModel.searchResults) { result in
                        searchResultRow(result)
                    }
                }

                // Added holdings
                if !viewModel.pendingHoldings.isEmpty {
                    if isSearching && !viewModel.searchResults.isEmpty {
                        Divider()
                            .padding(.vertical, Theme.Spacing.xs)
                    }

                    HStack {
                        Text("Adicionados")
                            .font(.system(size: Theme.FontSize.caption, weight: .medium))
                            .foregroundStyle(Color.tqSecondaryText)
                        Spacer()
                        Text("\(viewModel.holdingCount)")
                            .font(.system(size: Theme.FontSize.caption, weight: .bold))
                            .foregroundStyle(Color.tqAccentGreen)
                    }

                    ForEach(viewModel.pendingHoldings) { holding in
                        holdingRow(holding)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .safeAreaInset(edge: .top, spacing: Theme.Spacing.sm) {
            searchField
        }
        .onAppear {
            let service = backendService
            debouncer.start { query in
                (try? await service.searchStocks(query: query)) ?? []
            }
        }
        .onDisappear {
            debouncer.stop()
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.tqSecondaryText)
            TextField("Buscar ticker (ex: ITUB3, PETR4)", text: $viewModel.searchQuery)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                #endif
                .autocorrectionDisabled()
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    viewModel.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.tqSecondaryText)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Color.tqCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
        .padding(.horizontal, Theme.Spacing.lg)
        .onChange(of: viewModel.searchQuery) { _, newValue in
            debouncer.send(newValue)
        }
        .onChange(of: debouncer.results) { _, newResults in
            viewModel.searchResults = newResults
        }
        .onChange(of: debouncer.isSearching) { _, searching in
            viewModel.isSearching = searching
        }
    }

    // MARK: - Rows

    private func searchResultRow(_ result: StockSearchResultDTO) -> some View {
        let alreadyAdded = viewModel.pendingHoldings.contains {
            $0.ticker.uppercased() == result.symbol.uppercased()
        }

        return Button {
            guard !alreadyAdded else { return }
            withAnimation {
                viewModel.addHolding(from: result)
            }
        } label: {
            TQCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.symbol)
                            .font(.system(size: Theme.FontSize.body, weight: .semibold))
                            .foregroundStyle(alreadyAdded ? Color.tqSecondaryText : Color.primary)
                        if let name = result.name {
                            Text(name)
                                .font(.system(size: Theme.FontSize.caption))
                                .foregroundStyle(Color.tqSecondaryText)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if alreadyAdded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.tqAccentGreen)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.tqAccentGreen)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func holdingRow(_ holding: PendingHolding) -> some View {
        TQCard {
            HStack {
                Image(systemName: holding.assetClass.icon)
                    .foregroundStyle(holding.assetClass.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.ticker)
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    Text(holding.displayName)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundStyle(Color.tqSecondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    withAnimation { viewModel.removeHolding(id: holding.id) }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

#Preview {
    AddHoldingsStepView(viewModel: OnboardingViewModel())
}
