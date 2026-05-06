import SwiftUI
import GroveDomain

struct AddHoldingsStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.backendService) private var backendService
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var selectedTab = 0
    @State private var debouncer = SearchDebouncer()
    @State private var importViewModel = ImportViewModel()
    @State private var hoveredHoldingID: UUID?
    @State private var resultToAdd: StockSearchResultDTO?

    private var isSearching: Bool {
        !viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                regularBody
            } else {
                compactBody
            }
        }
        .onAppear {
            let service = backendService
            debouncer.start { query in
                (try? await service.searchStocks(query: query, assetClass: nil)) ?? []
            }
        }
        .onDisappear {
            debouncer.stop()
        }
        .onChange(of: viewModel.searchQuery) { _, newValue in
            debouncer.send(newValue)
        }
        .onChange(of: debouncer.results) { _, newResults in
            viewModel.searchResults = newResults
        }
        .onChange(of: debouncer.isSearching) { _, searching in
            viewModel.isSearching = searching
        }
        .sheet(item: $resultToAdd) { result in
            AddAssetDetailSheet(
                searchResult: result,
                mode: .onboarding(onAdd: { pending in
                    withAnimation { viewModel.appendPending(pending) }
                })
            )
        }
    }

    // MARK: - Compact (iPhone)

    private var compactBody: some View {
        VStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Add Your Assets")
                    .font(.system(size: Theme.FontSize.title2, weight: .bold))

                Text("Add the tickers you already own or want to track. Transactions will be recorded later.")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Color.tqSecondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)

            Picker("Mode", selection: $selectedTab) {
                Text("Search").tag(0)
                Text("Import").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.lg)

            if selectedTab == 0 {
                compactSearchTab
            } else {
                ImportView(
                    viewModel: importViewModel,
                    existingTickers: Set(viewModel.pendingHoldings.map { $0.ticker.uppercased() }),
                    confirmLabel: "Add"
                ) { positions in
                    withAnimation {
                        viewModel.addHoldings(from: positions)
                    }
                }
                .onAppear {
                    importViewModel.maxSelectable = Holding.remainingSlots(currentCount: viewModel.pendingHoldings.count)
                }
            }
        }
    }

    private var compactSearchTab: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.xs) {
                if viewModel.isSearching {
                    ProgressView()
                        .padding(.vertical, Theme.Spacing.md)
                } else if isSearching {
                    ForEach(viewModel.searchResults) { result in
                        compactSearchResultRow(result)
                    }
                }

                if !viewModel.pendingHoldings.isEmpty {
                    if isSearching && !viewModel.searchResults.isEmpty {
                        Divider()
                            .padding(.vertical, Theme.Spacing.xs)
                    }

                    HStack {
                        Text("Added")
                            .font(.system(size: Theme.FontSize.caption, weight: .medium))
                            .foregroundStyle(Color.tqSecondaryText)
                        Spacer()
                        Text("\(viewModel.holdingCount)")
                            .font(.system(size: Theme.FontSize.caption, weight: .bold))
                            .foregroundStyle(Color.tqAccentGreen)
                    }

                    ForEach(viewModel.pendingHoldings) { holding in
                        compactHoldingRow(holding)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .safeAreaInset(edge: .top, spacing: Theme.Spacing.sm) {
            compactSearchField
        }
    }

    private var compactSearchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.tqSecondaryText)
            TextField("Search ticker (e.g.: ITUB3, PETR4)", text: $viewModel.searchQuery)
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
    }

    private func compactSearchResultRow(_ result: StockSearchResultDTO) -> some View {
        let alreadyAdded = viewModel.pendingHoldings.contains {
            $0.ticker.uppercased() == result.symbol.uppercased()
        }

        return Button {
            guard !alreadyAdded else { return }
            resultToAdd = result
        } label: {
            TQCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.displaySymbol)
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
                    Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                        .foregroundStyle(Color.tqAccentGreen)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func compactHoldingRow(_ holding: PendingHolding) -> some View {
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

    // MARK: - Regular (iPad / Mac) — two-column split

    private var regularBody: some View {
        VStack(spacing: 0) {
            regularHeader
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)

            Divider()

            HStack(spacing: 0) {
                leftPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                rightPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var regularHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Add Your Assets")
                    .font(.system(size: Theme.FontSize.title3, weight: .semibold))
                Text("Add the tickers you already own or want to track. Transactions will be recorded later.")
                    .font(.caption)
                    .foregroundStyle(Color.tqSecondaryText)
            }
            Spacer()
            Button {
                withAnimation { selectedTab = selectedTab == 0 ? 1 : 0 }
            } label: {
                Label(
                    selectedTab == 0 ? "Import from CSV…" : "Back to search",
                    systemImage: selectedTab == 0 ? "square.and.arrow.down" : "magnifyingglass"
                )
                .font(.caption.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.tqAccentGreen)
        }
    }

    @ViewBuilder
    private var leftPane: some View {
        if selectedTab == 0 {
            VStack(spacing: 0) {
                regularSearchField
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                Divider()
                regularResultsList
            }
        } else {
            ImportView(
                viewModel: importViewModel,
                existingTickers: Set(viewModel.pendingHoldings.map { $0.ticker.uppercased() }),
                confirmLabel: "Add"
            ) { positions in
                withAnimation {
                    viewModel.addHoldings(from: positions)
                    selectedTab = 0
                }
            }
            .onAppear {
                importViewModel.maxSelectable = Holding.remainingSlots(currentCount: viewModel.pendingHoldings.count)
            }
        }
    }

    private var regularSearchField: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.tqSecondaryText)
            TextField("Search ticker (e.g. ITUB3, AAPL)", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
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
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .stroke(Color.tqSecondaryText.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var regularResultsList: some View {
        if viewModel.isSearching {
            VStack {
                ProgressView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !isSearching {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.title)
                    .foregroundStyle(Color.tqSecondaryText.opacity(0.4))
                Text("Search for tickers to add")
                    .font(.caption)
                    .foregroundStyle(Color.tqSecondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.searchResults.isEmpty {
            VStack(spacing: Theme.Spacing.sm) {
                Text("No results")
                    .font(.caption)
                    .foregroundStyle(Color.tqSecondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.searchResults) { result in
                        regularSearchResultRow(result)
                        Divider().opacity(0.5)
                    }
                }
            }
        }
    }

    private func regularSearchResultRow(_ result: StockSearchResultDTO) -> some View {
        let alreadyAdded = viewModel.pendingHoldings.contains {
            $0.ticker.uppercased() == result.symbol.uppercased()
        }

        return Button {
            guard !alreadyAdded else { return }
            resultToAdd = result
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .foregroundStyle(alreadyAdded ? Color.tqSecondaryText : Color.tqAccentGreen)
                    .font(.body)
                VStack(alignment: .leading, spacing: 1) {
                    Text(result.displaySymbol)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(alreadyAdded ? Color.tqSecondaryText : Color.primary)
                    if let name = result.name, !name.isEmpty {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(Color.tqSecondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if alreadyAdded {
                    Text("Added")
                        .font(.caption2)
                        .foregroundStyle(Color.tqSecondaryText)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(alreadyAdded)
    }

    @ViewBuilder
    private var rightPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Selected")
                    .font(.system(.body, weight: .semibold))
                Spacer()
                Text("\(viewModel.holdingCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.tqAccentGreen)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)

            Divider()

            if viewModel.pendingHoldings.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundStyle(Color.tqSecondaryText.opacity(0.4))
                    Text("No assets yet")
                        .font(.caption)
                        .foregroundStyle(Color.tqSecondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.pendingHoldings) { holding in
                            regularHoldingRow(holding)
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
    }

    private func regularHoldingRow(_ holding: PendingHolding) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: holding.assetClass.icon)
                .foregroundStyle(holding.assetClass.color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(holding.ticker)
                    .font(.system(.body, weight: .semibold))
                Text(holding.displayName)
                    .font(.caption)
                    .foregroundStyle(Color.tqSecondaryText)
                    .lineLimit(1)
            }
            Spacer()
            if hoveredHoldingID == holding.id {
                Button {
                    withAnimation { viewModel.removeHolding(id: holding.id) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.tqSecondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredHoldingID = hovering ? holding.id : (hoveredHoldingID == holding.id ? nil : hoveredHoldingID)
        }
    }
}

#Preview("Compact") {
    AddHoldingsStepView(viewModel: OnboardingViewModel())
        .environment(\.horizontalSizeClass, .compact)
}

#Preview("Regular") {
    AddHoldingsStepView(viewModel: OnboardingViewModel())
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 720, height: 500)
}
