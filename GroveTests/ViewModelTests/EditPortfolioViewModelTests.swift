import Testing
import Foundation
import SwiftData
import GroveDomain
@testable import Grove

@Suite(.serialized)
struct EditPortfolioViewModelTests {

    @MainActor
    @Test func deletePortfolioRemovesIt() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Doomed")
        ctx.insert(portfolio)
        try ctx.save()

        let vm = EditPortfolioViewModel()
        vm.delete(portfolio: portfolio, modelContext: ctx)

        let remaining = try ctx.fetch(FetchDescriptor<Portfolio>())
        #expect(remaining.isEmpty)
    }

    @MainActor
    @Test func deletePortfolioCascadesHoldings() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Doomed")
        ctx.insert(portfolio)
        let h = Holding(ticker: "X", currentPrice: 1, assetClass: .acoesBR)
        ctx.insert(h)
        h.portfolio = portfolio
        try ctx.save()

        let vm = EditPortfolioViewModel()
        vm.delete(portfolio: portfolio, modelContext: ctx)

        let leftover = try ctx.fetch(FetchDescriptor<Holding>())
        #expect(leftover.isEmpty, "Cascade rule on Portfolio.holdings removes the holding too")
    }
}
