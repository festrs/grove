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

    // MARK: - applyBulkStatus

    @MainActor
    @Test func applyBulkStatusSetsStatusOnAllSelected() throws {
        let ctx = try makeTestContext()
        let (portfolio, holdings) = seedTestData(ctx)

        let vm = AssetClassHoldingsViewModel(assetClass: .acoesBR)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        let h1 = try #require(holdings.first { $0.ticker == "ITUB3" })
        let h4 = try #require(holdings.first { $0.ticker == "WEGE3" })
        let h2 = try #require(holdings.first { $0.ticker == "BTLG11" })

        vm.applyBulkStatus(
            .quarentena,
            to: [h1.persistentModelID, h4.persistentModelID],
            modelContext: ctx,
            portfolio: portfolio,
            displayCurrency: .brl,
            rates: Self.rates
        )

        #expect(h1.status == .quarentena)
        #expect(h4.status == .quarentena)
        #expect(h2.status == .aportar, "other classes untouched")
    }

    @MainActor
    @Test func applyBulkStatusPersistsToContext() throws {
        let ctx = try makeTestContext()
        let (portfolio, holdings) = seedTestData(ctx)
        let h1 = try #require(holdings.first { $0.ticker == "ITUB3" })
        let id = h1.persistentModelID

        let vm = AssetClassHoldingsViewModel(assetClass: .acoesBR)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        vm.applyBulkStatus(
            .vender,
            to: [id],
            modelContext: ctx,
            portfolio: portfolio,
            displayCurrency: .brl,
            rates: Self.rates
        )

        let fetched: Holding = try #require(ctx.model(for: id) as? Holding)
        #expect(fetched.statusRaw == HoldingStatus.vender.rawValue)
    }

    @MainActor
    @Test func applyBulkStatusEmptySelectionIsNoOp() throws {
        let ctx = try makeTestContext()
        let (portfolio, holdings) = seedTestData(ctx)
        let h1 = try #require(holdings.first { $0.ticker == "ITUB3" })
        let beforeStatus = h1.status

        let vm = AssetClassHoldingsViewModel(assetClass: .acoesBR)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        vm.applyBulkStatus(
            .quarentena,
            to: [],
            modelContext: ctx,
            portfolio: portfolio,
            displayCurrency: .brl,
            rates: Self.rates
        )

        #expect(h1.status == beforeStatus)
    }

    // MARK: - applyBulkAssetClass

    @MainActor
    @Test func applyBulkAssetClassMovesSelectedOutOfCurrentScreen() throws {
        let ctx = try makeTestContext()
        let (portfolio, holdings) = seedTestData(ctx)
        let h1 = try #require(holdings.first { $0.ticker == "ITUB3" })

        let vm = AssetClassHoldingsViewModel(assetClass: .acoesBR)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)
        let countBefore = vm.holdings.count

        vm.applyBulkAssetClass(
            .fiis,
            to: [h1.persistentModelID],
            modelContext: ctx,
            portfolio: portfolio,
            displayCurrency: .brl,
            rates: Self.rates
        )

        #expect(vm.holdings.count == countBefore - 1)
        #expect(!vm.holdings.contains(where: { $0.persistentModelID == h1.persistentModelID }))
        #expect(h1.assetClass == .fiis)
    }

    @MainActor
    @Test func applyBulkAssetClassPreservesCurrency() throws {
        // Move between BRL-native classes only — `computeSummary` sums per-class
        // money and crashes on mixed currencies in the same class, so a cross-
        // currency move (e.g. .acoesBR → .usStocks) hits that unrelated invariant
        // during the reload. This test still proves the bulk method doesn't
        // touch `currencyRaw` on its own.
        let ctx = try makeTestContext()
        let (portfolio, holdings) = seedTestData(ctx)
        let h1 = try #require(holdings.first { $0.ticker == "ITUB3" })
        #expect(h1.currency == .brl)

        let vm = AssetClassHoldingsViewModel(assetClass: .acoesBR)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        vm.applyBulkAssetClass(
            .fiis,
            to: [h1.persistentModelID],
            modelContext: ctx,
            portfolio: portfolio,
            displayCurrency: .brl,
            rates: Self.rates
        )

        #expect(h1.currency == .brl, "currency must not auto-flip on class reassignment")
    }

    // MARK: - applyBulkDelete

    @MainActor
    @Test func applyBulkDeleteRemovesHoldings() throws {
        let ctx = try makeTestContext()
        let (portfolio, holdings) = seedTestData(ctx)
        let h1 = try #require(holdings.first { $0.ticker == "ITUB3" })
        let h4 = try #require(holdings.first { $0.ticker == "WEGE3" })

        let vm = AssetClassHoldingsViewModel(assetClass: .acoesBR)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        vm.applyBulkDelete(
            ids: [h1.persistentModelID, h4.persistentModelID],
            modelContext: ctx,
            portfolio: portfolio,
            displayCurrency: .brl,
            rates: Self.rates
        )

        #expect(vm.holdings.isEmpty)
    }

    @MainActor
    @Test func applyBulkDeleteEmptySelectionIsNoOp() throws {
        let ctx = try makeTestContext()
        let (portfolio, _) = seedTestData(ctx)

        let vm = AssetClassHoldingsViewModel(assetClass: .acoesBR)
        vm.loadData(portfolio: portfolio, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)
        let countBefore = vm.holdings.count

        vm.applyBulkDelete(
            ids: [],
            modelContext: ctx,
            portfolio: portfolio,
            displayCurrency: .brl,
            rates: Self.rates
        )

        #expect(vm.holdings.count == countBefore)
    }
}
