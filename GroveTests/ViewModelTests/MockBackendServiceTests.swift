import Testing
import Foundation
import GroveDomain
@testable import Grove

/// Class-filter behaviour on `MockBackendService.searchStocks`. The mock
/// drives previews and most unit tests, so its filter has to mirror the
/// backend contract: when an asset class is supplied, only results whose
/// `inferredAssetClass` matches come back.
struct MockBackendServiceTests {

    @Test func returnsAllMatchesWhenAssetClassIsNil() async throws {
        let svc = MockBackendService()
        let results = try await svc.searchStocks(query: "petr", assetClass: nil)
        #expect(results.contains { $0.symbol == "PETR4.SA" })
    }

    /// Class-scoped *callers* (today: none — every screen passes nil so users
    /// can discover and add assets from any class) should still get a mixed
    /// result set when assetClass is nil. Guards against a future regression
    /// where someone re-introduces auto-scoping at the call site.
    @Test func nilAssetClassReturnsResultsAcrossDifferentClasses() async throws {
        let svc = MockBackendService()
        // "a" matches AAPL (US) and ITAU (BR via name) — proves the search
        // is genuinely cross-class when unscoped.
        let results = try await svc.searchStocks(query: "a", assetClass: nil)
        let classes = Set(results.compactMap { $0.inferredAssetClass })
        #expect(classes.contains(.usStocks))
        #expect(classes.contains(.acoesBR))
    }

    @Test func filtersToBrazilianStocksWhenScopedToAcoesBR() async throws {
        let svc = MockBackendService()
        // Query matches both PETR4 (BR) and would surface AAPL on a name
        // search; "p" is broad enough to catch both. Filter must drop AAPL.
        let results = try await svc.searchStocks(query: "p", assetClass: .acoesBR)
        let symbols = results.map(\.symbol)
        #expect(symbols.contains("PETR4.SA"))
        #expect(!symbols.contains("AAPL"), "US stocks must not appear in BR-scoped results")
    }

    @Test func filtersToUSStocksWhenScopedToUsStocks() async throws {
        let svc = MockBackendService()
        let results = try await svc.searchStocks(query: "a", assetClass: .usStocks)
        let symbols = results.map(\.symbol)
        #expect(symbols.contains("AAPL"))
        #expect(!symbols.contains("PETR4.SA"))
        #expect(!symbols.contains("ITUB3.SA"))
    }

    @Test func returnsEmptyWhenScopedClassHasNoMatchingMockData() async throws {
        let svc = MockBackendService()
        // Mock has no FII or REIT or crypto fixtures — scoping to those
        // classes should yield zero results regardless of the query.
        let fiis = try await svc.searchStocks(query: "anything", assetClass: .fiis)
        let reits = try await svc.searchStocks(query: "anything", assetClass: .reits)
        let crypto = try await svc.searchStocks(query: "anything", assetClass: .crypto)
        #expect(fiis.isEmpty)
        #expect(reits.isEmpty)
        #expect(crypto.isEmpty)
    }

    @Test func querySubstringMatchIsCaseInsensitive() async throws {
        let svc = MockBackendService()
        let lower = try await svc.searchStocks(query: "apple", assetClass: nil)
        let upper = try await svc.searchStocks(query: "APPLE", assetClass: nil)
        #expect(lower.map(\.symbol) == upper.map(\.symbol))
        #expect(lower.contains { $0.symbol == "AAPL" })
    }
}
