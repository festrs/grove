import SwiftUI
import GroveDomain

#if os(macOS)
/// Mac-only ⌘N quick-add sheet. Opens via the CommandGroup in `GroveApp`
/// (or a NotificationCenter signal) and presents the standard
/// `AddAssetDetailSheet` once the user picks a search result.
struct MacAddHoldingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.backendService) private var backendService

    @State private var query = ""
    @State private var debouncer = SearchDebouncer()
    @State private var selectedResult: StockSearchResultDTO?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search ticker or name (e.g. ITUB3, AAPL)", text: $query)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                }
                .padding(10)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .padding()

                if debouncer.isSearching {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Searching…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                List(debouncer.results) { result in
                    Button {
                        selectedResult = result
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.tqAccentGreen)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.displaySymbol).font(.headline)
                                if let name = result.name, !name.isEmpty {
                                    Text(name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)

                if !debouncer.isSearching && debouncer.results.isEmpty && query.count >= 2 {
                    Text("No results for \"\(query)\"")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .frame(minWidth: 520, minHeight: 420)
            .navigationTitle("Add Holding")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: query) { _, newValue in
                debouncer.send(newValue)
            }
            .task {
                let svc = backendService
                debouncer.start { q in
                    (try? await svc.searchStocks(query: q, assetClass: nil)) ?? []
                }
            }
            .sheet(item: $selectedResult, onDismiss: { dismiss() }) { result in
                AddAssetDetailSheet(searchResult: result)
            }
        }
    }
}
#endif
