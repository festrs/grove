import SwiftUI
import SwiftData
import GroveDomain

/// Class-scoped add sheet. Two paths:
/// 1. Search → tap a real result → caller presents `AddAssetDetailSheet`
///    with the screen's class fixed (we dismiss this sheet and hand the
///    selected DTO back via `onSelectResult`).
/// 2. No-results / custom path → "Add custom ticker" row creates a local
///    `Holding` directly via `AssetClassHoldingsViewModel.addCustomTicker`,
///    no detail screen.
struct AddToClassSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: AssetClassHoldingsViewModel
    let onSelectResult: (StockSearchResultDTO) -> Void

    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !viewModel.searchText.isEmpty {
                            PortfolioSearchResultsList(
                                results: viewModel.debouncer.results,
                                isSearching: viewModel.debouncer.isSearching,
                                searchText: viewModel.searchText,
                                isAlreadyAdded: viewModel.isAlreadyAdded,
                                onAdd: handleResultTapped,
                                onRemove: { _ in /* removal handled in main list */ }
                            )

                            customTickerRow
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(Theme.Spacing.md)
                        }
                    }
                }
            }
            .background(Color.tqBackground)
            .navigationTitle("Add to \(viewModel.assetClass.displayName)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                let service = backendService
                viewModel.debouncer.start { query in
                    // Search shows results from every asset class so users can
                    // discover assets that don't fit the current screen and
                    // also reach the "Add custom ticker" path below.
                    (try? await service.searchStocks(query: query, assetClass: nil)) ?? []
                }
                fieldFocused = true
            }
            .onChange(of: viewModel.searchText) { _, newValue in
                viewModel.debouncer.send(newValue)
            }
            .onDisappear {
                viewModel.searchText = ""
                viewModel.debouncer.results = []
                viewModel.errorMessage = nil
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 520, minHeight: 480, idealHeight: 560)
        #endif
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Ticker or name", text: $viewModel.searchText)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                #endif
                .autocorrectionDisabled()
                .focused($fieldFocused)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                    viewModel.debouncer.results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.tqCardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var customTickerRow: some View {
        let trimmed = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty,
           !viewModel.debouncer.isSearching,
           !viewModel.isAlreadyAdded(trimmed) {
            Button {
                if viewModel.addCustomTicker(symbol: trimmed, modelContext: modelContext) {
                    dismiss()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.dashed")
                        .foregroundStyle(viewModel.assetClass.color)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add \"\(trimmed.uppercased())\" as custom ticker")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Local-only. Edit price and details after adding.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.horizontal, Theme.Spacing.md)
        }
    }

    private func handleResultTapped(_ result: StockSearchResultDTO) {
        // Hand the selected DTO back to the parent so it can present
        // AddAssetDetailSheet with the class fixed. We dismiss first to
        // avoid stacking two sheets.
        dismiss()
        DispatchQueue.main.async {
            onSelectResult(result)
        }
    }
}
