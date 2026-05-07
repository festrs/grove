import Testing
import Foundation
import SwiftData
import GroveDomain
@testable import Grove

@Suite(.serialized)
struct AddAssetViewModelTests {

    private static let sampleSearch = StockSearchResultDTO(
        id: "HGLG11.SA", symbol: "HGLG11.SA", name: "CSHG Logistica",
        type: "fund",
        price: MoneyDTO(amount: "180.00", currency: "BRL"),
        currency: "BRL", change: 0,
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
        #expect(vm.ownsPosition == false)
        #expect(vm.isValid == true, "Track-only mode is always valid")
    }

    // MARK: - isValid

    @MainActor
    @Test func isValidWhenOwnsPositionRequiresPositiveQuantityAndPrice() {
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch)
        vm.ownsPosition = true
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
        vm.ownsPosition = true
        vm.quantityText = "1,5"
        vm.priceText = "32,75"
        #expect(vm.isValid == true)
    }

    // MARK: - addAsset (with position)

    @MainActor
    @Test func addAssetWithPositionPersistsHoldingAndContribution() async throws {
        let ctx = try makeTestContext()
        let backend = MockBackendService()
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch)
        vm.ownsPosition = true
        vm.quantityText = "10"
        vm.priceText = "180.00"
        vm.date = Date(timeIntervalSince1970: 1_700_000_000)

        let added = vm.addAsset(modelContext: ctx, backendService: backend, rates: StaticRates(brlPerUsd: 5))

        #expect(added == true)
        #expect(vm.errorMessage == nil)
        let holdings = try ctx.fetch(FetchDescriptor<Holding>())
        #expect(holdings.count == 1)
        #expect(holdings.first?.ticker == "HGLG11.SA")
        #expect(holdings.first?.status == .aportar)
        let contributions = try ctx.fetch(FetchDescriptor<Contribution>())
        #expect(contributions.count == 1)
        #expect(contributions.first?.shares == 10)
    }

    @MainActor
    @Test func addAssetWithPositionReturnsFalseWhenFieldsEmpty() throws {
        let ctx = try makeTestContext()
        let backend = MockBackendService()
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch)
        vm.ownsPosition = true
        // Empty fields with position toggle on — invalid
        let added = vm.addAsset(modelContext: ctx, backendService: backend, rates: StaticRates(brlPerUsd: 5))
        #expect(added == false)
        #expect(try ctx.fetch(FetchDescriptor<Holding>()).isEmpty)
    }

    // MARK: - addAsset (track only)

    @MainActor
    @Test func addAssetTrackOnlyPersistsStudyHoldingWithoutContribution() async throws {
        let ctx = try makeTestContext()
        let backend = MockBackendService()
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch)
        // ownsPosition stays false
        let added = vm.addAsset(modelContext: ctx, backendService: backend, rates: StaticRates(brlPerUsd: 5))

        #expect(added == true)
        let holdings = try ctx.fetch(FetchDescriptor<Holding>())
        #expect(holdings.count == 1)
        #expect(holdings.first?.status == .estudo)
        let contributions = try ctx.fetch(FetchDescriptor<Contribution>())
        #expect(contributions.isEmpty, "Track-only mode must not create a Contribution")
    }

    @MainActor
    @Test func addAssetBlockedByFreeTierLimit() throws {
        UserDefaults.standard.set(false, forKey: AppConstants.Debug.unlimitedHoldingsKey)
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
        vm.ownsPosition = true
        vm.quantityText = "10"
        vm.priceText = "100"

        let added = vm.addAsset(modelContext: ctx, backendService: backend, rates: StaticRates(brlPerUsd: 5))
        #expect(added == false)
        #expect(vm.errorMessage == Holding.freeTierLimitMessage)
    }

    // MARK: - toPendingHolding (onboarding bridge)

    @MainActor
    @Test func toPendingHoldingTrackOnlyHasZeroQuantity() {
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch)
        let pending = vm.toPendingHolding(rates: StaticRates(brlPerUsd: 5))
        #expect(pending.ticker == "HGLG11.SA")
        #expect(pending.quantity == 0)
        #expect(pending.status == .estudo)
        #expect(pending.averagePrice == nil)
        #expect(pending.purchaseDate == nil)
    }

    // MARK: - Forced asset class

    @MainActor
    @Test func forcedAssetClassOverridesDetection() {
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch, assetClass: .crypto)
        // Sample search would normally detect as .fiis (HGLG11 + fund)
        #expect(vm.detectedClass == .crypto)
        #expect(vm.hasFixedClass == true)
    }

    @MainActor
    @Test func absentForcedClassFallsBackToDetection() {
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch)
        #expect(vm.detectedClass == .fiis)
        #expect(vm.hasFixedClass == false)
    }

    // MARK: - Custom ticker

    @MainActor
    @Test func customFactoryDefaultsToAcoesBRWithPickerEnabled() {
        let vm = AddAssetViewModel.custom(symbol: " mycoin ")
        #expect(vm.isCustom == true)
        #expect(vm.searchResult.symbol == "MYCOIN")
        #expect(vm.detectedClass == .acoesBR, "Custom add starts on a sane default; user can repick")
        #expect(vm.hasFixedClass == false, "Custom always exposes the class picker")
        #expect(vm.priceText.isEmpty, "Custom never pre-fills price — there's no backend quote")
    }

    @MainActor
    @Test func customAddPersistsHoldingWithIsCustomTrue() async throws {
        let ctx = try makeTestContext()
        let backend = MockBackendService()
        let vm = AddAssetViewModel.custom(symbol: "myCoin")
        vm.detectedClass = .crypto

        let added = vm.addAsset(modelContext: ctx, backendService: backend, rates: StaticRates(brlPerUsd: 5))

        #expect(added == true)
        let holdings = try ctx.fetch(FetchDescriptor<Holding>())
        let custom = try #require(holdings.first { $0.ticker == "MYCOIN" })
        #expect(custom.isCustom == true)
        #expect(custom.assetClass == .crypto)
        #expect(custom.status == .estudo, "Track-only custom defaults to .estudo")
        #expect(custom.currentPrice == 0, "Custom track-only enters with zero price; user fills from detail screen")
    }

    @MainActor
    @Test func customAddWithPositionRecordsContribution() async throws {
        let ctx = try makeTestContext()
        let backend = MockBackendService()
        let vm = AddAssetViewModel.custom(symbol: "MYCOIN")
        vm.detectedClass = .crypto
        vm.ownsPosition = true
        vm.quantityText = "2"
        vm.priceText = "150"

        let added = vm.addAsset(modelContext: ctx, backendService: backend, rates: StaticRates(brlPerUsd: 5))

        #expect(added == true)
        let holding = try #require(try ctx.fetch(FetchDescriptor<Holding>()).first)
        #expect(holding.isCustom == true)
        #expect(holding.status == .aportar)
        let contributions = try ctx.fetch(FetchDescriptor<Contribution>())
        #expect(contributions.count == 1)
        #expect(contributions.first?.shares == 2)
    }

    @MainActor
    @Test func toPendingHoldingWithPositionCarriesQuantityAndPrice() {
        let vm = AddAssetViewModel(searchResult: Self.sampleSearch)
        vm.ownsPosition = true
        vm.quantityText = "5"
        vm.priceText = "200"
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        vm.date = date

        let pending = vm.toPendingHolding(rates: StaticRates(brlPerUsd: 5))
        #expect(pending.quantity == 5)
        #expect(pending.status == .aportar)
        #expect(pending.averagePrice == 200)
        #expect(pending.purchaseDate == date)
    }
}
