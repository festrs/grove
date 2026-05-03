import SwiftUI
import GroveDomain

/// Stocks-search results pane shared by Compact (iPhone) and Wide
/// (iPad + macOS) portfolio views. Tapping a row toggles the asset:
/// `onAdd` when the result isn't in the portfolio yet, `onRemove` when it
/// already is.
struct PortfolioSearchResultsList: View {
    let results: [StockSearchResultDTO]
    let isSearching: Bool
    let searchText: String
    let isAlreadyAdded: (String) -> Bool
    let onAdd: (StockSearchResultDTO) -> Void
    let onRemove: (StockSearchResultDTO) -> Void

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
                            if added { onRemove(result) } else { onAdd(result) }
                        } label: {
                            row(result: result, added: added)
                        }
                        .buttonStyle(.plain)
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
            leadingIcon(added: added)

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
                Text("Tap to remove")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func leadingIcon(added: Bool) -> some View {
        if added {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(Color.tqNegative)
                .font(.title3)
        } else {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.tqAccentGreen)
                .font(.title3)
        }
    }
}
