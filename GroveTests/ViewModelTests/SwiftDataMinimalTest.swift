import Testing
import Foundation
import SwiftData
@testable import Grove

@Suite(.serialized)
struct SwiftDataMinimalTest {

    @MainActor
    @Test func portfolioWithAllocations() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Test")
        ctx.insert(portfolio)
        portfolio.classAllocations = [.acoesBR: 40, .fiis: 30]
        try ctx.save()
        #expect(portfolio.classAllocations[.acoesBR] == 40)
    }

    @MainActor
    @Test func holdingWithRelationship() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Test")
        ctx.insert(portfolio)
        let h = Holding(ticker: "ITUB3.SA", quantity: 100, assetClass: .acoesBR)
        ctx.insert(h)
        h.portfolio = portfolio
        try ctx.save()
        #expect(portfolio.holdings.count == 1)
    }

    @MainActor
    @Test func fullSeedTest() throws {
        let ctx = try makeTestContext()
        let (portfolio, holdings) = seedTestData(ctx)
        #expect(portfolio.name == "Test Portfolio")
        #expect(holdings.count == 4)
        #expect(portfolio.holdings.count == 4)
    }
}
