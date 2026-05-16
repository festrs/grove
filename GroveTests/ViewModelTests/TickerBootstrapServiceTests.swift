import Testing
import Foundation
import SwiftData
import GroveDomain
@testable import Grove

@Suite(.serialized)
struct TickerBootstrapServiceTests {

    // MARK: - bootstrap (price + DY summary, every add path)

    @MainActor
    @Test func bootstrapWritesPriceAndDividendYield() async throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Test")
        ctx.insert(portfolio)
        let holding = Holding(
            ticker: "HGLG11", displayName: "HGLG",
            currentPrice: 0, dividendYield: 0,
            assetClass: .fiis, status: .estudo
        )
        ctx.insert(holding)
        holding.portfolio = portfolio
        try ctx.save()

        let backend = StubBackend(
            quoteAmount: "180.50",
            quoteCurrency: "BRL",
            dyBySymbol: ["HGLG11": "6.65"]
        )
        let service = TickerBootstrapService()

        await service.bootstrap(holdings: [holding], backendService: backend)

        #expect(holding.currentPrice == Decimal(string: "180.50"))
        #expect(holding.lastPriceUpdate != nil)
        // Backend already returns dividend_yield in percent; assigned directly.
        #expect(holding.dividendYield == Decimal(string: "6.65"))
    }

    @MainActor
    @Test func bootstrapNoOpWhenHoldingsEmpty() async throws {
        let backend = StubBackend()
        let service = TickerBootstrapService()
        await service.bootstrap(holdings: [], backendService: backend)
        let calls = await backend.calls
        #expect(calls.isEmpty)
    }

    @MainActor
    @Test func bootstrapSilentlyIgnoresProviderErrors() async throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Test")
        ctx.insert(portfolio)
        let holding = Holding(
            ticker: "HGLG11", displayName: "HGLG",
            currentPrice: 0, assetClass: .fiis, status: .estudo
        )
        ctx.insert(holding)
        holding.portfolio = portfolio
        try ctx.save()

        let backend = ThrowingBackend()
        let service = TickerBootstrapService()
        // Should not throw — bootstrap is best-effort, manual refresh is the
        // recovery path.
        await service.bootstrap(holdings: [holding], backendService: backend)
        #expect(holding.currentPrice == 0, "Throwing backend leaves the price at 0")
    }

    // MARK: - refreshDividendsAfterTransaction (only for .aportar holdings with a Transaction)

    @MainActor
    @Test func refreshAfterTransactionPassesSinceFromFirstTransaction() async throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Test")
        ctx.insert(portfolio)
        let holding = Holding(
            ticker: "HGLG11", displayName: "HGLG",
            currentPrice: 100, assetClass: .fiis, status: .aportar
        )
        ctx.insert(holding)
        holding.portfolio = portfolio

        let firstDate = Date(timeIntervalSince1970: 1_700_000_000) // a stable past date
        let secondDate = firstDate.addingTimeInterval(86_400 * 30)
        let c1 = Transaction(date: firstDate, amount: 1000, shares: 10, pricePerShare: 100)
        c1.holding = holding
        let c2 = Transaction(date: secondDate, amount: 1000, shares: 10, pricePerShare: 100)
        c2.holding = holding
        ctx.insert(c1)
        ctx.insert(c2)
        holding.recalculateFromTransactions()
        try ctx.save()

        let backend = StubBackend()
        let service = TickerBootstrapService()
        await service.refreshDividendsAfterTransaction(
            holding: holding,
            modelContext: ctx,
            backendService: backend
        )

        let refreshCalls = await backend.refreshCalls
        #expect(refreshCalls.count == 1)
        #expect(refreshCalls.first?.symbols == ["HGLG11"])
        #expect(refreshCalls.first?.assetClass == "fiis")
        #expect(refreshCalls.first?.since == firstDate, "Must scope by the FIRST transaction, not the latest")
    }

    @MainActor
    @Test func refreshAfterTransactionSkipsWhenNoTransactions() async throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Test")
        ctx.insert(portfolio)
        let holding = Holding(
            ticker: "STUDY11.SA", displayName: "Study",
            currentPrice: 100, assetClass: .fiis, status: .estudo
        )
        ctx.insert(holding)
        holding.portfolio = portfolio
        try ctx.save()

        let backend = StubBackend()
        let service = TickerBootstrapService()
        await service.refreshDividendsAfterTransaction(
            holding: holding,
            modelContext: ctx,
            backendService: backend
        )

        let refreshCalls = await backend.refreshCalls
        #expect(refreshCalls.isEmpty, "Study holdings have no transactions, so the dividend scrape must not fire")
    }
}

// MARK: - Test doubles

private actor StubBackend: BackendServiceProtocol {
    struct RefreshCall: Equatable {
        let symbols: [String]
        let assetClass: String
        let since: Date?
    }
    var calls: [String] = []
    var refreshCalls: [RefreshCall] = []

    private let quoteAmount: String
    private let quoteCurrency: String
    private let dyBySymbol: [String: String]

    init(
        quoteAmount: String = "10.00",
        quoteCurrency: String = "BRL",
        dyBySymbol: [String: String] = [:]
    ) {
        self.quoteAmount = quoteAmount
        self.quoteCurrency = quoteCurrency
        self.dyBySymbol = dyBySymbol
    }

    func searchStocks(query: String, assetClass: AssetClassType?) async throws -> [StockSearchResultDTO] { [] }
    func fetchStockQuote(symbol: String) async throws -> StockQuoteDTO {
        calls.append("quote:\(symbol)")
        return StockQuoteDTO(symbol: symbol, name: symbol,
                             price: MoneyDTO(amount: quoteAmount, currency: quoteCurrency),
                             currency: quoteCurrency)
    }
    func fetchBatchQuotes(symbols: [String]) async throws -> [BatchQuoteDTO] {
        calls.append("batch:\(symbols.joined(separator: ","))")
        return symbols.map {
            BatchQuoteDTO(
                symbol: $0,
                name: $0,
                price: MoneyDTO(amount: quoteAmount, currency: quoteCurrency),
                currency: quoteCurrency,
                dividendYield: dyBySymbol[$0]
            )
        }
    }
    func fetchExchangeRate(pair: String) async throws -> BackendExchangeRateDTO {
        BackendExchangeRateDTO(pair: pair, rate: 5)
    }
    func fetchDividendsForSymbols(symbols: [String], year: Int?) async throws -> [MobileDividendDTO] { [] }
    func refreshDividends(symbols: [String], assetClass: String, since: Date?) async throws -> DividendRefreshResultDTO {
        refreshCalls.append(.init(symbols: symbols, assetClass: assetClass, since: since))
        return DividendRefreshResultDTO(scraped: symbols.count, newRecords: 0, failed: [])
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

private actor ThrowingBackend: BackendServiceProtocol {
    enum E: Error { case nope }
    func searchStocks(query: String, assetClass: AssetClassType?) async throws -> [StockSearchResultDTO] { throw E.nope }
    func fetchStockQuote(symbol: String) async throws -> StockQuoteDTO { throw E.nope }
    func fetchBatchQuotes(symbols: [String]) async throws -> [BatchQuoteDTO] { throw E.nope }
    func fetchExchangeRate(pair: String) async throws -> BackendExchangeRateDTO { throw E.nope }
    func fetchDividendsForSymbols(symbols: [String], year: Int?) async throws -> [MobileDividendDTO] { throw E.nope }
    func refreshDividends(symbols: [String], assetClass: String, since: Date?) async throws -> DividendRefreshResultDTO { throw E.nope }
    func trackSymbol(symbol: String, assetClass: String) async throws { throw E.nope }
    func untrackSymbol(symbol: String) async throws {}
    func syncTrackedSymbols(pairs: [(symbol: String, assetClass: String)]) async throws {}
    func fetchPriceHistory(symbol: String, period: String) async throws -> [PriceHistoryPointDTO] { throw E.nope }
    func fetchFundamentals(symbol: String) async throws -> FundamentalsDTO { throw E.nope }
    func importPortfolio(fileData: Data, filename: String) async throws -> [ImportedPosition] { throw E.nope }
    func redeemCode(_ code: String) async throws -> RedeemCodeResultDTO { throw E.nope }
}
