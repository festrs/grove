import Testing
import Foundation
@testable import Grove

@Suite(.serialized)
struct RateStoreTests {

    @MainActor
    @Test func defaultsBeforeRefresh() {
        let store = RateStore()
        #expect(store.brlPerUsd == Decimal(string: "5.15"))
        #expect(store.lastUpdated == nil)
    }

    @MainActor
    @Test func sameCurrencyReturnsOne() {
        let store = RateStore()
        #expect(store.rate(from: .brl, to: .brl) == 1)
        #expect(store.rate(from: .usd, to: .usd) == 1)
    }

    @MainActor
    @Test func usdToBrlReturnsBrlPerUsd() {
        let store = RateStore()
        let rate = store.rate(from: .usd, to: .brl)
        #expect(rate == store.brlPerUsd)
    }

    @MainActor
    @Test func brlToUsdReturnsInverse() {
        let store = RateStore()
        let rate = store.rate(from: .brl, to: .usd)
        #expect(rate == 1 / store.brlPerUsd)
    }

    @MainActor
    @Test func refreshUpdatesValueOnSuccess() async {
        let store = RateStore()
        let mock = MockBackendService()
        await store.refresh(using: mock)
        #expect(store.brlPerUsd == Decimal(5.12))
        #expect(store.lastUpdated != nil)
    }
}
