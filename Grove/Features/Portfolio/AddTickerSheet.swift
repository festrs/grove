import SwiftUI
import SwiftData
import GroveDomain

/// Global add-ticker sheet. Single entry point for adding holdings to the
/// portfolio — search hits the backend unfiltered (the asset class is
/// derived from the result via `AssetClassType.detect`), and a "custom
/// ticker" row at the bottom routes through the same `AddAssetDetailSheet`
/// for symbols the backend doesn't know about.
///
/// The parent presents the detail sheet after this one dismisses (we hand
/// the selection back via `onSelect`); SwiftUI doesn't like stacking two
/// fullscreen sheets directly.
enum AddTickerSelection: Identifiable {
    case found(StockSearchResultDTO)
    case custom(symbol: String)

    var id: String {
        switch self {
        case .found(let dto): return "found:\(dto.id)"
        case .custom(let symbol): return "custom:\(symbol)"
        }
    }
}

struct AddTickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AddTickerSheetViewModel()
    @FocusState private var fieldFocused: Bool

    let onSelect: (AddTickerSelection) -> Void

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
                        } else {
                            hint
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
            .navigationTitle("Add Ticker")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                viewModel.loadExistingTickers(modelContext: modelContext)
                let service = backendService
                viewModel.debouncer.start { query in
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

    private var hint: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Search for a ticker or company")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Or type a symbol and add it as a custom ticker.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, Theme.Spacing.md)
    }

    @ViewBuilder
    private var customTickerRow: some View {
        let trimmed = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if viewModel.canAddAsCustom(trimmed: trimmed, isSearching: viewModel.debouncer.isSearching) {
            Button {
                handleCustomTapped(symbol: trimmed)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.dashed")
                        .foregroundStyle(Color.tqAccentGreen)
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
        // Dismiss before invoking the parent so it can stack the detail
        // sheet without SwiftUI complaining about competing presentations.
        dismiss()
        DispatchQueue.main.async {
            onSelect(.found(result))
        }
    }

    private func handleCustomTapped(symbol: String) {
        dismiss()
        DispatchQueue.main.async {
            onSelect(.custom(symbol: symbol))
        }
    }
}
