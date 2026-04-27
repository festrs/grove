import Foundation
import Observation
import GroveDomain

@Observable
@MainActor
final class RateStore: ExchangeRates {
    private(set) var brlPerUsd: Decimal = 5.15
    private(set) var lastUpdated: Date? = nil

    func refresh(using backend: any BackendServiceProtocol) async {
        do {
            let dto = try await backend.fetchExchangeRate(pair: "USD-BRL")
            let rate = Decimal(dto.rate)
            guard rate > 0 else {
                print("[RateStore] received non-positive rate \(dto.rate); keeping last value")
                return
            }
            brlPerUsd = rate
            lastUpdated = Date()
        } catch {
            print("[RateStore] refresh failed: \(error.localizedDescription); keeping last value")
        }
    }

    nonisolated func rate(from source: Currency, to target: Currency) -> Decimal {
        if source == target { return 1 }
        let snapshot = MainActor.assumeIsolated { brlPerUsd }
        switch (source, target) {
        case (.usd, .brl): return snapshot
        case (.brl, .usd): return 1 / snapshot
        default: return 1
        }
    }
}
