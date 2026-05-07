import Foundation

public extension String {
    /// Canonical storage form for a ticker symbol: uppercased and trimmed.
    /// The `.SA` suffix on Brazilian tickers is owned by the backend — when a
    /// symbol arrives via search, quotes, dividends, etc. it already carries
    /// `.SA` if the asset class is a B3 listing. iOS persists exactly what the
    /// backend sent.
    ///
    /// Use this whenever a ticker crosses a write boundary (Holding init, API
    /// call key, lookup map).
    var normalizedTicker: String {
        uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// UI-only form: strips the trailing `.SA` so cards/labels show `ITUB3`
    /// rather than `ITUB3.SA`. Storage stays canonical (`.SA`-suffixed for BR).
    var displayTicker: String {
        hasSuffix(".SA") ? String(dropLast(3)) : self
    }
}

public enum TickerParser {
    /// Extract uppercased tickers from free-form text — one per line, with the
    /// first column kept when a separator (",", ";", "\t") is present. Filters
    /// out empties, anything longer than 10 chars, and entries that have no
    /// letters.
    public static func parse(_ text: String) -> [String] {
        var results: [String] = []
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            var ticker = trimmed
            for sep in [",", ";", "\t"] {
                let split = trimmed.components(separatedBy: sep)
                if split.count >= 2 {
                    ticker = split[0].trimmingCharacters(in: .whitespaces)
                    break
                }
            }

            let upper = ticker.uppercased()
            guard !upper.isEmpty, upper.count <= 10 else { continue }
            guard upper.contains(where: { $0.isLetter }) else { continue }
            results.append(upper)
        }
        return results
    }
}
