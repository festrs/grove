import SwiftUI

struct AddHoldingsStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.backendService) private var backendService

    @State private var selectedTab = 0
    @State private var quantityText: String = ""
    @State private var selectedResult: StockSearchResultDTO?
    @State private var showQuantityInput = false

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // MARK: - Header
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Adicione seus ativos")
                    .font(.system(size: Theme.FontSize.title2, weight: .bold))

                Text("\(viewModel.holdingCount) ativo\(viewModel.holdingCount == 1 ? "" : "s") adicionado\(viewModel.holdingCount == 1 ? "" : "s")")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Color.tqSecondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)

            // MARK: - Tab Picker
            Picker("Modo", selection: $selectedTab) {
                Text("Digitar").tag(0)
                Text("Colar da planilha").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.lg)

            if selectedTab == 0 {
                searchTab
            } else {
                pasteTab
            }

            // MARK: - Holdings List
            if !viewModel.pendingHoldings.isEmpty {
                holdingsList
            }

            Spacer(minLength: 0)
        }
        .sheet(isPresented: $showQuantityInput) {
            quantitySheet
                .presentationDetents([.height(220)])
        }
    }

    // MARK: - Search Tab

    private var searchTab: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.tqSecondaryText)
                TextField("Buscar ticker (ex: ITUB3, PETR4)", text: $viewModel.searchQuery)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task {
                            await viewModel.searchTicker(query: viewModel.searchQuery, service: backendService)
                        }
                    }
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

            if viewModel.isSearching {
                ProgressView()
                    .padding(.top, Theme.Spacing.md)
            } else if !viewModel.searchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.xs) {
                        ForEach(viewModel.searchResults) { result in
                            searchResultRow(result)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
                .frame(maxHeight: 180)
            }

            Button {
                Task {
                    await viewModel.searchTicker(query: viewModel.searchQuery, service: backendService)
                }
            } label: {
                Text("Buscar")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.tqAccentGreen)
            }
            .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func searchResultRow(_ result: StockSearchResultDTO) -> some View {
        let alreadyAdded = viewModel.pendingHoldings.contains {
            $0.ticker.uppercased() == result.symbol.uppercased()
        }

        return Button {
            guard !alreadyAdded else { return }
            selectedResult = result
            quantityText = ""
            showQuantityInput = true
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
                    } else if let type = result.type {
                        Text(type)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundStyle(Color.tqSecondaryText)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Paste Tab

    private var pasteTab: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("Cole seus ativos no formato: TICKER, QUANTIDADE")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundStyle(Color.tqSecondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.lg)

            TextEditor(text: $viewModel.csvText)
                .font(.system(size: Theme.FontSize.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(Theme.Spacing.sm)
                .frame(minHeight: 120, maxHeight: 160)
                .background(Color.tqCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                .padding(.horizontal, Theme.Spacing.lg)

            Text("Exemplo:\nITUB3, 556\nPETR4, 200\nXPML11, 50")
                .font(.system(size: Theme.FontSize.caption, design: .monospaced))
                .foregroundStyle(Color.tqSecondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.lg)

            Button {
                viewModel.importFromCSV()
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Importar")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Color.tqAccentGreen)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .disabled(viewModel.csvText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Holdings List

    private var holdingsList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Ativos adicionados")
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundStyle(Color.tqSecondaryText)
                .padding(.horizontal, Theme.Spacing.lg)

            ScrollView {
                LazyVStack(spacing: Theme.Spacing.xs) {
                    ForEach(viewModel.pendingHoldings) { holding in
                        holdingRow(holding)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .frame(maxHeight: 200)
        }
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
                    Text("\(holding.quantity as NSDecimalNumber) cotas")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundStyle(Color.tqSecondaryText)
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

    // MARK: - Quantity Sheet

    private var quantitySheet: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                if let result = selectedResult {
                    Text("Quantas cotas de \(result.symbol)?")
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                }

                TextField("Quantidade", text: $quantityText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, Theme.Spacing.lg)

                Button {
                    if let result = selectedResult,
                       let qty = Decimal(string: quantityText.replacingOccurrences(of: ",", with: ".")),
                       qty > 0 {
                        viewModel.addHolding(from: result, quantity: qty)
                        showQuantityInput = false
                    }
                } label: {
                    Text("Adicionar")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Color.tqAccentGreen)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .padding(.top, Theme.Spacing.md)
            .navigationTitle("Quantidade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showQuantityInput = false }
                }
            }
        }
    }
}

#Preview {
    AddHoldingsStepView(viewModel: OnboardingViewModel())
}
