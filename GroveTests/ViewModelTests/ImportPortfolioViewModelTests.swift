import Testing
import Foundation
import SwiftData
import GroveDomain
@testable import Grove

@Suite(.serialized)
struct ImportPortfolioViewModelTests {

    private func makePosition(
        ticker: String,
        quantity: Double = 0,
        price: Double = 100,
        assetClass: AssetClassType = .acoesBR
    ) -> ImportedPosition {
        ImportedPosition(
            ticker: ticker,
            displayName: ticker,
            quantity: quantity,
            currentPrice: price,
            assetClass: assetClass.rawValue,
            totalValue: quantity * price
        )
    }

    @MainActor
    @Test func importInsertsHoldingsAndAttachesToPortfolio() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "T")
        ctx.insert(portfolio)
        try ctx.save()

        let vm = ImportPortfolioViewModel()
        let backend = MockBackendService()

        vm.confirmImport(
            positions: [
                makePosition(ticker: "ITUB3", quantity: 0),
                makePosition(ticker: "HGLG11", quantity: 0, assetClass: .fiis),
            ],
            portfolio: portfolio,
            modelContext: ctx,
            backendService: backend
        )

        let holdings = try ctx.fetch(FetchDescriptor<Holding>())
        #expect(holdings.count == 2)
        #expect(holdings.allSatisfy { $0.portfolio === portfolio })
    }

    @MainActor
    @Test func importPromotesPositionsWithQuantityToAportar() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "T")
        ctx.insert(portfolio)
        try ctx.save()

        let vm = ImportPortfolioViewModel()
        let backend = MockBackendService()

        vm.confirmImport(
            positions: [makePosition(ticker: "ITUB3", quantity: 100, price: 30)],
            portfolio: portfolio,
            modelContext: ctx,
            backendService: backend
        )

        let h = try ctx.fetch(FetchDescriptor<Holding>()).first { $0.ticker == "ITUB3" }!
        #expect(h.status == .aportar)
        #expect(h.quantity == 100, "Opening contribution recalculates quantity")
    }

    @MainActor
    @Test func importLeavesZeroQuantityInEstudo() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "T")
        ctx.insert(portfolio)
        try ctx.save()

        let vm = ImportPortfolioViewModel()
        let backend = MockBackendService()

        vm.confirmImport(
            positions: [makePosition(ticker: "STUDY", quantity: 0)],
            portfolio: portfolio,
            modelContext: ctx,
            backendService: backend
        )

        let h = try ctx.fetch(FetchDescriptor<Holding>()).first { $0.ticker == "STUDY" }!
        #expect(h.status == .estudo)
        #expect(h.contributions.isEmpty, "No quantity → no opening contribution")
    }

    @MainActor
    @Test func importEmptyPositionsIsNoOp() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "T")
        ctx.insert(portfolio)
        try ctx.save()

        let vm = ImportPortfolioViewModel()
        let backend = MockBackendService()

        vm.confirmImport(
            positions: [],
            portfolio: portfolio,
            modelContext: ctx,
            backendService: backend
        )
        let holdings = try ctx.fetch(FetchDescriptor<Holding>())
        #expect(holdings.isEmpty)
    }
}
