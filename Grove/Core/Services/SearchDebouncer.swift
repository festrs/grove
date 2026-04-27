import AsyncAlgorithms
import Foundation
import GroveDomain

/// Debounces search queries using AsyncAlgorithms `AsyncChannel`.
/// Each new query is sent into the channel; the consumer reads
/// debounced values and performs the actual search.
@Observable
final class SearchDebouncer {
    var results: [StockSearchResultDTO] = []
    var isSearching = false

    private let channel = AsyncChannel<String>()
    private var consumeTask: Task<Void, Never>?

    func start(using search: @escaping (String) async -> [StockSearchResultDTO]) {
        consumeTask?.cancel()
        consumeTask = Task { [channel] in
            for await query in channel.debounce(for: .milliseconds(500)) {
                guard !Task.isCancelled else { break }
                await MainActor.run { self.isSearching = true }
                let fetched = await search(query)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.results = fetched
                    self.isSearching = false
                }
            }
        }
    }

    func send(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            results = []
            isSearching = false
            return
        }
        Task { await channel.send(trimmed) }
    }

    func stop() {
        consumeTask?.cancel()
        consumeTask = nil
    }

    deinit {
        consumeTask?.cancel()
    }
}
