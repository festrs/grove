import SwiftUI
import GroveDomain

/// Stocks-search results pane shared by Compact (iPhone) and Wide
/// (iPad + macOS) portfolio views. Tap a row to add it as `.estudo` —
/// the caller wires the actual add via `onAdd`.
struct PortfolioSearchResultsList: View {
    let results: [StockSearchResultDTO]
    let isSearching: Bool
    let searchText: String
    let isAlreadyAdded: (String) -> Bool
    let onAdd: (StockSearchResultDTO) -> Void

    var body: some View {
        Group {
            if isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Searching...").foregroundStyle(.secondary)
                }
                .padding(.vertical, Theme.Spacing.sm)
            }

            if !results.isEmpty {
                LazyVStack(spacing: 0) {
                    ForEach(results, id: \.id) { result in
                        let added = isAlreadyAdded(result.symbol)
                        Button {
                            guard !added else { return }
                            onAdd(result)
                        } label: {
                            row(result: result, added: added)
                        }
                        .buttonStyle(.plain)
                        .disabled(added)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 8)
                    }

                    Divider()
                        .padding(.horizontal, Theme.Spacing.md)
                }
            }

            if !isSearching && results.isEmpty && searchText.count >= 2 {
                Text("No results for \"\(searchText)\"")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Theme.Spacing.md)
            }
        }
    }

    @ViewBuilder
    private func row(result: StockSearchResultDTO, added: Bool) -> some View {
        HStack(spacing: 12) {
            leadingIcon(for: result, added: added)

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
                Text("Added")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func leadingIcon(for result: StockSearchResultDTO, added: Bool) -> some View {
        if added {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.tqAccentGreen)
                .font(.title3)
        } else if result.isCrypto {
            Image(systemName: "bitcoinsign.circle.fill")
                .foregroundStyle(AssetClassType.crypto.color)
                .font(.title3)
        } else {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.tqAccentGreen)
                .font(.title3)
        }
    }
}
