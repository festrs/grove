import AsyncAlgorithms
import Foundation

/// Coalesces a burst of "reload" signals into a single delayed invocation.
/// Mirrors `SearchDebouncer` but with a `Void` payload — callers just `send()`
/// and the consumer fires once after the bursts settle.
///
/// Used by the dashboard so that the cold-launch fan-in of Holdings,
/// Contributions, and DividendPayments (each routed through SwiftData
/// `@Query`'s `.onChange`) collapses into a single `loadData` call instead of
/// 4–7 back-to-back ones. Same instance is reused for the entire view
/// lifetime; cancel-and-resume is handled internally.
@Observable
final class ReloadDebouncer {

    private let channel = AsyncChannel<Void>()
    private var consumeTask: Task<Void, Never>?

    /// Begin consuming `send()` events. The supplied closure runs on the main
    /// actor after the debounce window settles. Calling `start` again cancels
    /// any previous consumer — handy if the closure needs fresh captures
    /// (e.g. when the SwiftUI environment changes).
    func start(interval: Duration = .milliseconds(50), perform: @escaping @MainActor () -> Void) {
        consumeTask?.cancel()
        consumeTask = Task { [channel] in
            for await _ in channel.debounce(for: interval) {
                guard !Task.isCancelled else { break }
                await MainActor.run { perform() }
            }
        }
    }

    func send() {
        Task { [channel] in await channel.send(()) }
    }

    func stop() {
        consumeTask?.cancel()
        consumeTask = nil
    }

    deinit { consumeTask?.cancel() }
}
