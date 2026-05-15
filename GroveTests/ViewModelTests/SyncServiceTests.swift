import Testing
import Foundation
import SwiftData
import GroveDomain
@testable import Grove

@Suite(.serialized)
struct SyncServiceTests {

    @MainActor
    @Test func syncPricesWritesPriceAndDividendYieldFromQuote() async throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Test")
        ctx.insert(portfolio)
        let holding = Holding(
            ticker: "ITUB3", displayName: "Itau",
            currentPrice: 0, dividendYield: 0,
            assetClass: .acoesBR, status: .aportar
        )
        ctx.insert(holding)
        holding.portfolio = portfolio
        try ctx.save()

        let backend = SyncStubBackend(
            quoteAmount: "32.50",
            dyBySymbol: ["ITUB3": "7.96"]
        )

        try await SyncService().syncPrices(modelContext: ctx, backendService: backend)

        #expect(holding.currentPrice == Decimal(string: "32.50"))
        #expect(holding.lastPriceUpdate != nil)
        // Backend already returns DY in percent; assigned directly.
        #expect(holding.dividendYield == Decimal(string: "7.96"))
    }

    @MainActor
    @Test func syncPricesPreservesExistingYieldWhenBackendReturnsNil() async throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Test")
        ctx.insert(portfolio)
        let holding = Holding(
            ticker: "BTC", displayName: "Bitcoin",
            currentPrice: 100, dividendYield: 5,
            assetClass: .crypto, status: .aportar
        )
        ctx.insert(holding)
        holding.portfolio = portfolio
        try ctx.save()

        let backend = SyncStubBackend(
            quoteAmount: "350000",
            dyBySymbol: [:] // no DY for crypto
        )

        try await SyncService().syncPrices(modelContext: ctx, backendService: backend)

        #expect(holding.currentPrice == Decimal(string: "350000"))
        #expect(holding.dividendYield == 5, "Nil DY from backend must not stomp the existing value")
    }
}

private actor SyncStubBackend: BackendServiceProtocol {
    private let quoteAmount: String
    private let dyBySymbol: [String: String]

    init(quoteAmount: String, dyBySymbol: [String: String]) {
        self.quoteAmount = quoteAmount
        self.dyBySymbol = dyBySymbol
    }

    func searchStocks(query: String, assetClass: AssetClassType?) async throws -> [StockSearchResultDTO] { [] }
    func fetchStockQuote(symbol: String) async throws -> StockQuoteDTO {
        StockQuoteDTO(symbol: symbol, name: symbol, price: MoneyDTO(amount: quoteAmount, currency: "BRL"), currency: "BRL")
    }
    func fetchBatchQuotes(symbols: [String]) async throws -> [BatchQuoteDTO] {
        symbols.map {
            BatchQuoteDTO(
                symbol: $0,
                name: $0,
                price: MoneyDTO(amount: quoteAmount, currency: "BRL"),
                currency: "BRL",
                dividendYield: dyBySymbol[$0]
            )
        }
    }
    func fetchExchangeRate(pair: String) async throws -> BackendExchangeRateDTO {
        BackendExchangeRateDTO(pair: pair, rate: 5)
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
        FundamentalsDTO(
            symbol: symbol,
            ipoYears: nil, ipoRating: nil,
            epsGrowthPct: nil, epsRating: nil,
            currentNetDebtEbitda: nil, highDebtYearsPct: nil, debtRating: nil,
            profitableYearsPct: nil, profitRating: nil,
            compositeScore: nil, updatedAt: nil
        )
    }
    func importPortfolio(fileData: Data, filename: String) async throws -> [ImportedPosition] { [] }
    func redeemCode(_ code: String) async throws -> RedeemCodeResultDTO {
        RedeemCodeResultDTO(valid: false, unlocks: [])
    }
}
