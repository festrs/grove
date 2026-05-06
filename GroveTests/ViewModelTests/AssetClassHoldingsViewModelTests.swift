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

    // The custom-ticker path now lives in `AddAssetViewModel.custom(symbol:)`
    // (see `AddAssetViewModelTests`), and the "already added" check moved to
    // `AddTickerSheetViewModel`. Tests for those behaviours live with the
    // corresponding VMs.

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
