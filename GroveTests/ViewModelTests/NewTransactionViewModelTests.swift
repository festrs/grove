import Testing
import Foundation
import SwiftData
import GroveDomain
@testable import Grove

@Suite(.serialized)
struct NewTransactionViewModelTests {

    // MARK: - Initial state

    @MainActor
    @Test func initialStateForBuy() {
        let vm = NewTransactionViewModel(transactionType: .buy)
        #expect(vm.errorMessage == nil)
        #expect(vm.selectedHolding == nil)
        #expect(vm.isNewAsset == false)
        #expect(vm.isValid == false)
    }

    // MARK: - isValid (buy)

    @MainActor
    @Test func isValidBuyRequiresAssetQtyAndPrice() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)

        let vm = NewTransactionViewModel(transactionType: .buy)
        // Pick existing holding but no qty/price → invalid
        vm.selectedHolding = holdings[0]
        #expect(vm.isValid == false)

        vm.quantityText = "10"
        vm.priceText = "32"
        #expect(vm.isValid == true)
    }

    @MainActor
    @Test func isValidBuyForNewAssetUsesNewTicker() {
        let vm = NewTransactionViewModel(transactionType: .buy)
        vm.isNewAsset = true
        vm.newTicker = "ABC"
        vm.quantityText = "1"
        vm.priceText = "1"
        #expect(vm.isValid == true)
    }

    // MARK: - isValid (sell guards quantity)

    @MainActor
    @Test func isValidSellRejectsOverQuantity() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)

        let vm = NewTransactionViewModel(transactionType: .sell)
        vm.selectedHolding = holdings[0]
        vm.priceText = "32"
        // Holding seeded with quantity 100, sell 200 → invalid
        vm.quantityText = "200"
        #expect(vm.isValid == false)
        // Sell 50 → valid
        vm.quantityText = "50"
        #expect(vm.isValid == true)
    }

    // MARK: - submit (buy with existing holding)

    @MainActor
    @Test func submitBuyExistingCreatesContributionAndPromotesEstudo() async throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)
        let study = holdings.first { $0.ticker == "WEGE3" }!
        #expect(study.status == .estudo, "WEGE3 was seeded as study")

        let backend = MockBackendService()
        let vm = NewTransactionViewModel(transactionType: .buy)
        vm.selectedHolding = study
        vm.quantityText = "5"
        vm.priceText = "40"

        let ok = vm.submit(modelContext: ctx, backendService: backend)
        #expect(ok == true)
        #expect(study.status == .aportar, "First buy on a study holding promotes to aportar")
        let transactions = try ctx.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.contains { $0.holding?.ticker == "WEGE3" })
    }

    // MARK: - submit (buy with new asset)

    @MainActor
    @Test func submitBuyNewAssetInsertsHolding() async throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "T")
        ctx.insert(portfolio)
        try ctx.save()

        let backend = MockBackendService()
        let vm = NewTransactionViewModel(transactionType: .buy)
        vm.isNewAsset = true
        vm.newTicker = "BBAS3"
        vm.newDisplayName = "Banco do Brasil"
        vm.newAssetClass = .acoesBR
        vm.quantityText = "10"
        vm.priceText = "30"

        let ok = vm.submit(modelContext: ctx, backendService: backend)
        #expect(ok == true)
        let holdings = try ctx.fetch(FetchDescriptor<Holding>())
        #expect(holdings.contains { $0.ticker == "BBAS3" })
    }

    // MARK: - submit (sell to zero deletes holding)

    @MainActor
    @Test func submitSellToZeroDeletesHolding() async throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "T")
        ctx.insert(portfolio)
        let h = Holding(ticker: "X", quantity: 10, currentPrice: 5, assetClass: .acoesBR, status: .aportar)
        ctx.insert(h)
        h.portfolio = portfolio
        let opening = Transaction(date: .now, amount: 50, shares: 10, pricePerShare: 5)
        ctx.insert(opening)
        opening.holding = h
        h.recalculateFromTransactions()
        try ctx.save()

        let backend = MockBackendService()
        let vm = NewTransactionViewModel(transactionType: .sell)
        vm.selectedHolding = h
        vm.quantityText = "10"
        vm.priceText = "5"

        let ok = vm.submit(modelContext: ctx, backendService: backend)
        #expect(ok == true)
        let leftover = try ctx.fetch(FetchDescriptor<Holding>()).filter { $0.ticker == "X" }
        #expect(leftover.isEmpty, "Selling all shares deletes the holding")
    }

    // MARK: - submit blocked when invalid

    @MainActor
    @Test func submitReturnsFalseWhenInvalid() throws {
        let ctx = try makeTestContext()
        _ = seedTestData(ctx)
        let backend = MockBackendService()

        let vm = NewTransactionViewModel(transactionType: .buy)
        // No asset selected, no qty/price
        let ok = vm.submit(modelContext: ctx, backendService: backend)
        #expect(ok == false)
    }
}
