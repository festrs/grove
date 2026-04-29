import Testing
import Foundation
import SwiftData
import GroveDomain
@testable import Grove

@Suite(.serialized)
struct AddAssetViewModelTests {

    private static let sampleSearch = StockSearchResultDTO(
        id: "HGLG11.SA", symbol: "HGLG11.SA", name: "CSHG Logistica",
        type: "fund", price: "180.00", currency: "BRL", change: "0",
        sector: nil, logo: nil
    )

    // MARK: - Initial state

    @MainActor
    @Test func initialStateDetectsAssetClassAndDefaults() {
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch)
        #expect(vm.detectedClass == .fiis, "FII tickers (11 + fund type) should detect as .fiis")
        #expect(vm.quantityText.isEmpty)
        #expect(vm.priceText.isEmpty)
        #expect(vm.errorMessage == nil)
        #expect(vm.isValid == false)
    }

    // MARK: - isValid

    @MainActor
    @Test func isValidRequiresPositiveQuantityAndPrice() {
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch)
        vm.quantityText = "0"
        vm.priceText = "100"
        #expect(vm.isValid == false)
        vm.quantityText = "10"
        vm.priceText = "0"
        #expect(vm.isValid == false)
        vm.quantityText = "10"
        vm.priceText = "100"
        #expect(vm.isValid == true)
    }

    @MainActor
    @Test func isValidAcceptsCommaDecimalSeparator() {
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch)
        vm.quantityText = "1,5"
        vm.priceText = "32,75"
        #expect(vm.isValid == true)
    }

    // MARK: - addAsset

    @MainActor
    @Test func addAssetPersistsHoldingAndContribution() async throws {
        let ctx = try makeTestContext()
        let backend = MockBackendService()
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch)
        vm.quantityText = "10"
        vm.priceText = "180.00"
        vm.date = Date(timeIntervalSince1970: 1_700_000_000)

        let added = vm.addAsset(modelContext: ctx, backendService: backend)

        #expect(added == true)
        #expect(vm.errorMessage == nil)
        let holdings = try ctx.fetch(FetchDescriptor<Holding>())
        #expect(holdings.count == 1)
        #expect(holdings.first?.ticker == "HGLG11.SA")
        let contributions = try ctx.fetch(FetchDescriptor<Contribution>())
        #expect(contributions.count == 1)
        #expect(contributions.first?.shares == 10)
    }

    @MainActor
    @Test func addAssetReturnsFalseWhenInvalid() throws {
        let ctx = try makeTestContext()
        let backend = MockBackendService()
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch)
        // Empty fields — invalid
        let added = vm.addAsset(modelContext: ctx, backendService: backend)
        #expect(added == false)
        #expect(try ctx.fetch(FetchDescriptor<Holding>()).isEmpty)
    }

    @MainActor
    @Test func addAssetBlockedByFreeTierLimit() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Full")
        ctx.insert(portfolio)
        for i in 0..<10 {
            let h = Holding(ticker: "T\(i)", displayName: "T\(i)", currentPrice: 1, assetClass: .acoesBR)
            h.portfolio = portfolio
            ctx.insert(h)
        }
        try ctx.save()

        let backend = MockBackendService()
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch)
        vm.quantityText = "10"
        vm.priceText = "100"

        let added = vm.addAsset(modelContext: ctx, backendService: backend)
        #expect(added == false)
        #expect(vm.errorMessage == Holding.freeTierLimitMessage)
    }
}
