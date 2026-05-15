import Testing
import Foundation
import SwiftData
import GroveDomain
@testable import Grove

@Suite(.serialized)
struct RedeemCodeViewModelTests {
    // MARK: - Initial state

    @MainActor
    @Test func initialStateIsIdle() {
        let vm = RedeemCodeViewModel()
        #expect(vm.code.isEmpty)
        #expect(vm.isSubmitting == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.didUnlock == false)
        #expect(vm.canSubmit == false, "Empty code can't be submitted")
    }

    @MainActor
    @Test func canSubmitOnceCodeIsNonEmpty() {
        let vm = RedeemCodeViewModel()
        vm.code = "GROVE-UNLIMITED"
        #expect(vm.canSubmit == true)
    }

    @MainActor
    @Test func whitespaceOnlyCodeCannotSubmit() {
        let vm = RedeemCodeViewModel()
        vm.code = "   "
        #expect(vm.canSubmit == false)
    }

    // MARK: - Successful redemption

    @MainActor
    @Test func successfulRedemptionUnlocksUserSettings() async throws {
        let ctx = try makeTestContext()
        let settings = UserSettings()
        #expect(settings.unlimitedAssetsUnlocked == false)
        ctx.insert(settings)
        try ctx.save()

        let vm = RedeemCodeViewModel()
        vm.code = "GROVE-UNLIMITED"  // MockBackendService accepts this code
        await vm.redeem(modelContext: ctx, backendService: MockBackendService())

        #expect(vm.didUnlock == true)
        #expect(vm.errorMessage == nil)
        #expect(vm.isSubmitting == false)

        let stored = try ctx.fetch(FetchDescriptor<UserSettings>()).first!
        #expect(stored.unlimitedAssetsUnlocked == true)
    }

    @MainActor
    @Test func successCreatesUserSettingsIfMissing() async throws {
        let ctx = try makeTestContext()  // no UserSettings seeded
        #expect(try ctx.fetch(FetchDescriptor<UserSettings>()).isEmpty)

        let vm = RedeemCodeViewModel()
        vm.code = "GROVE-UNLIMITED"
        await vm.redeem(modelContext: ctx, backendService: MockBackendService())

        let all = try ctx.fetch(FetchDescriptor<UserSettings>())
        #expect(all.count == 1, "VM creates a row when none exists so the unlock has somewhere to live")
        #expect(all.first!.unlimitedAssetsUnlocked == true)
    }

    @MainActor
    @Test func successTrimsLeadingTrailingWhitespace() async throws {
        let ctx = try makeTestContext()
        let settings = UserSettings()
        ctx.insert(settings)
        try ctx.save()

        let vm = RedeemCodeViewModel()
        vm.code = "  GROVE-UNLIMITED  "
        await vm.redeem(modelContext: ctx, backendService: MockBackendService())

        #expect(vm.didUnlock == true)
    }

    // MARK: - Failure paths

    @MainActor
    @Test func invalidCodeLeavesSettingsLocked() async throws {
        let ctx = try makeTestContext()
        let settings = UserSettings()
        ctx.insert(settings)
        try ctx.save()

        let vm = RedeemCodeViewModel()
        vm.code = "WRONG-CODE"
        await vm.redeem(modelContext: ctx, backendService: MockBackendService())

        #expect(vm.didUnlock == false)
        #expect(vm.errorMessage != nil, "User sees a friendly error")
        #expect(vm.isSubmitting == false)

        let stored = try ctx.fetch(FetchDescriptor<UserSettings>()).first!
        #expect(stored.unlimitedAssetsUnlocked == false)
    }

    @MainActor
    @Test func networkErrorSurfacedAsErrorMessage() async throws {
        let ctx = try makeTestContext()
        let settings = UserSettings()
        ctx.insert(settings)
        try ctx.save()

        let vm = RedeemCodeViewModel()
        vm.code = "GROVE-UNLIMITED"
        await vm.redeem(modelContext: ctx, backendService: FailingBackendService())

        #expect(vm.didUnlock == false)
        #expect(vm.errorMessage != nil)
        #expect(vm.isSubmitting == false)
    }
}

// MARK: - Test doubles

/// Throws on every call — used to assert the ViewModel handles network
/// failures without crashing or silently succeeding.
private actor FailingBackendService: BackendServiceProtocol {
    func searchStocks(query: String, assetClass: AssetClassType?) async throws -> [StockSearchResultDTO] { [] }
    func fetchStockQuote(symbol: String) async throws -> StockQuoteDTO {
        throw APIError.unknown("stub")
    }
    func fetchBatchQuotes(symbols: [String]) async throws -> [BatchQuoteDTO] { [] }
    func fetchExchangeRate(pair: String) async throws -> BackendExchangeRateDTO {
        throw APIError.unknown("stub")
    }
    func fetchDividendsForSymbols(symbols: [String], year: Int?) async throws -> [MobileDividendDTO] { [] }
    func refreshDividends(symbols: [String], assetClass: String, since: Date?) async throws -> DividendRefreshResultDTO {
        DividendRefreshResultDTO(scraped: 0, newRecords: 0, failed: [])
    }
    func trackSymbol(symbol: String, assetClass: String) async throws {}
    func untrackSymbol(symbol: String) async throws {}
    func syncTrackedSymbols(pairs: [(symbol: String, assetClass: String)]) async throws {}
    func fetchPriceHistory(symbol: String, period: String) async throws -> [PriceHistoryPointDTO] { [] }
    func fetchFundamentals(symbol: String) async throws -> FundamentalsDTO {
        throw APIError.unknown("stub")
    }
    func importPortfolio(fileData: Data, filename: String) async throws -> [ImportedPosition] { [] }
    func redeemCode(_ code: String) async throws -> RedeemCodeResultDTO {
        throw APIError.unknown("network down")
    }
}
