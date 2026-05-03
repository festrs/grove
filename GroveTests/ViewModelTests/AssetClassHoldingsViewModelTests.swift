import Testing
import Foundation
import SwiftData
import GroveDomain
import GroveRepositories
@testable import Grove

@Suite(.serialized)
struct AssetClassHoldingsViewModelTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    // MARK: - loadData scoping

    @MainActor
    @Test func loadDataScopesHoldingsToClass() throws {
        let ctx = try makeTestContext()
        let (portfolio, _) = seedTestData(ctx)

        let vm = AssetClassHoldingsViewModel(assetClass: .acoesBR)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(!vm.holdings.isEmpty)
        #expect(vm.holdings.allSatisfy { $0.assetClass == .acoesBR })
    }

    @MainActor
    @Test func loadDataPopulatesClassTotalsAndTarget() throws {
        let ctx = try makeTestContext()
        let (portfolio, _) = seedTestData(ctx)

        let vm = AssetClassHoldingsViewModel(assetClass: .acoesBR)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.classTotalValue.amount > 0)
        #expect(vm.classTargetPercent == 40, "Settings seed gives acoesBR 40% target")
    }

    // MARK: - addCustomTicker

    @MainActor
    @Test func addCustomTickerCreatesLocalOnlyHolding() throws {
        let ctx = try makeTestContext()
        let (portfolio, _) = seedTestData(ctx)

        let vm = AssetClassHoldingsViewModel(assetClass: .crypto)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)
        let initialCount = try ctx.fetch(FetchDescriptor<Holding>()).count

        let added = vm.addCustomTicker(symbol: "myCoin", modelContext: ctx)

        #expect(added == true)
        let allHoldings = try ctx.fetch(FetchDescriptor<Holding>())
        #expect(allHoldings.count == initialCount + 1)
        let custom = try #require(allHoldings.first(where: { $0.ticker == "MYCOIN" }))
        #expect(custom.isCustom == true)
        #expect(custom.assetClass == .crypto)
        #expect(custom.status == .estudo)
        #expect(custom.currentPrice == 0)
        #expect(custom.displayName == "MYCOIN")
    }

    @MainActor
    @Test func addCustomTickerRejectsEmptyInput() throws {
        let ctx = try makeTestContext()
        let (portfolio, _) = seedTestData(ctx)

        let vm = AssetClassHoldingsViewModel(assetClass: .crypto)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.addCustomTicker(symbol: "   ", modelContext: ctx) == false)
        #expect(vm.addCustomTicker(symbol: "", modelContext: ctx) == false)
    }

    @MainActor
    @Test func addCustomTickerRejectsDuplicate() throws {
        let ctx = try makeTestContext()
        let (portfolio, _) = seedTestData(ctx)

        let vm = AssetClassHoldingsViewModel(assetClass: .acoesBR)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        // ITUB3 is already in the seeded portfolio under .acoesBR
        let added = vm.addCustomTicker(symbol: "ITUB3.SA", modelContext: ctx)
        #expect(added == false)
        #expect(vm.errorMessage != nil)
    }

    // MARK: - isAlreadyAdded

    @MainActor
    @Test func isAlreadyAddedMatchesCaseInsensitive() throws {
        let ctx = try makeTestContext()
        let (portfolio, _) = seedTestData(ctx)

        let vm = AssetClassHoldingsViewModel(assetClass: .acoesBR)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.isAlreadyAdded("itub3.sa") == true)
        #expect(vm.isAlreadyAdded("UNKNOWN") == false)
    }

    // MARK: - deleteHolding

    @MainActor
    @Test func deleteHoldingRemovesFromList() throws {
        let ctx = try makeTestContext()
        let (portfolio, holdings) = seedTestData(ctx)

        let vm = AssetClassHoldingsViewModel(assetClass: .acoesBR)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)
        let initialCount = vm.holdings.count
        let target = try #require(holdings.first { $0.assetClass == .acoesBR })

        vm.deleteHolding(target, modelContext: ctx, portfolio: portfolio, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.holdings.count == initialCount - 1)
    }
}
