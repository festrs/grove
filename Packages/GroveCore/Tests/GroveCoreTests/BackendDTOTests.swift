import Testing
import Foundation
import GroveDomain

struct BackendDTOTests {

    // MARK: - MoneyDTO

    @Test func moneyDTOParsesDecimalAmount() {
        let money = MoneyDTO(amount: "1234.56", currency: "BRL")
        #expect(money.decimalAmount == Decimal(string: "1234.56"))
    }

    @Test func moneyDTOHandlesInvalidAmount() {
        let money = MoneyDTO(amount: "not-a-number", currency: "BRL")
        #expect(money.decimalAmount == .zero)
    }

    // MARK: - ExchangeRate Decoding

    @Test func decodesExchangeRate() throws {
        let json = """
        {"pair": "USD-BRL", "rate": 5.12}
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(BackendExchangeRateDTO.self, from: json)
        #expect(dto.pair == "USD-BRL")
        #expect(dto.rate == 5.12)
    }

    // MARK: - StockSearchResult Decoding

    @Test func decodesStockSearchResult() throws {
        let json = """
        [
            {"id": "WEGE3.SA", "symbol": "WEGE3.SA", "name": "WEGE3", "type": "Common Stock"},
            {"id": "AAPL", "symbol": "AAPL", "name": "Apple Inc", "type": null}
        ]
        """.data(using: .utf8)!

        let results = try JSONDecoder().decode([StockSearchResultDTO].self, from: json)
        #expect(results.count == 2)
        #expect(results[0].id == "WEGE3.SA")
        #expect(results[0].symbol == "WEGE3.SA")
        #expect(results[1].type == nil)
    }

    @Test func stockSearchResultIsHashable() {
        let a = StockSearchResultDTO(id: "ITUB3.SA", symbol: "ITUB3.SA", name: "Itau", type: nil, price: nil, currency: nil, change: nil, sector: nil, logo: nil)

        let b = StockSearchResultDTO(id: "ITUB3.SA", symbol: "ITUB3.SA", name: "Itau Unibanco", type: "Stock", price: "46.37", currency: "BRL", change: nil, sector: nil, logo: nil)
        #expect(a == b, "Same id should be equal")
    }

    @Test func decodesEnrichedSearchResult() throws {
        let json = """
        [{"id": "HGLG11.SA", "symbol": "HGLG11.SA", "name": "HGLG11", "type": "fund", "price": "157.9", "currency": "BRL", "change": "0.23", "sector": "Miscellaneous", "logo": "https://icons.brapi.dev/icons/BRAPI.svg"}]
        """.data(using: .utf8)!

        let results = try JSONDecoder().decode([StockSearchResultDTO].self, from: json)
        #expect(results[0].type == "fund")
        #expect(results[0].price == "157.9")
        #expect(results[0].priceDecimal == Decimal(string: "157.9"))
        #expect(results[0].currency == "BRL")
        #expect(results[0].sector == "Miscellaneous")
    }

    @Test func displaySymbolStripsSA() {
        let dto = StockSearchResultDTO(id: "HGLG11.SA", symbol: "HGLG11.SA", name: "HGLG11", type: "fund", price: "157.9", currency: "BRL", change: nil, sector: nil, logo: nil)
        #expect(dto.displaySymbol == "HGLG11")
    }

    @Test func displaySymbolKeepsUSSymbol() {
        let dto = StockSearchResultDTO(id: "AAPL", symbol: "AAPL", name: "Apple Inc", type: nil, price: nil, currency: nil, change: nil, sector: nil, logo: nil)
        #expect(dto.displaySymbol == "AAPL")
    }

    @Test func displayDescriptionShowsFIIAndPrice() {
        let dto = StockSearchResultDTO(id: "HGLG11.SA", symbol: "HGLG11.SA", name: "HGLG11", type: "fund", price: "157.9", currency: "BRL", change: nil, sector: nil, logo: nil)
        #expect(dto.displayDescription == "FII · R$ 157.9")
    }

    @Test func displayDescriptionShowsNameAndStockAndPrice() {
        let dto = StockSearchResultDTO(id: "ITUB3.SA", symbol: "ITUB3.SA", name: "ITAU UNIBANCO HOLDING S.A.", type: "stock", price: "46.37", currency: "BRL", change: nil, sector: nil, logo: nil)
        #expect(dto.displayDescription == "ITAU UNIBANCO HOLDING S.A. · Acao BR · R$ 46.37")
    }

    @Test func displayDescriptionUSStockNoType() {
        let dto = StockSearchResultDTO(id: "AAPL", symbol: "AAPL", name: "Apple Inc", type: "Common Stock", price: nil, currency: nil, change: nil, sector: nil, logo: nil)
        #expect(dto.displayDescription == "Apple Inc")
    }

    @Test func displayDescriptionEmptyWhenNoData() {
        let dto = StockSearchResultDTO(id: "X", symbol: "X", name: "X", type: nil, price: nil, currency: nil, change: nil, sector: nil, logo: nil)
        #expect(dto.displayDescription == "")
    }

    // MARK: - AssetClassType.detect with apiType

    @Test func detectFundAsFII() {
        #expect(AssetClassType.detect(from: "HGLG11.SA", apiType: "fund") == .fiis)
    }

    @Test func detectStockAsAcoesBR() {
        #expect(AssetClassType.detect(from: "TAEE11.SA", apiType: "stock") == .acoesBR)
    }

    @Test func detectBDRAsUSStocks() {
        #expect(AssetClassType.detect(from: "AAPL34.SA", apiType: "bdr") == .usStocks)
    }

    @Test func detectCryptoFromApiType() {
        // DOGE is not in the symbol fallback list, so only the apiType branch can classify it as crypto.
        #expect(AssetClassType.detect(from: "DOGE", apiType: "crypto") == .crypto)
    }

    @Test func detectWithoutApiTypeFallsBackToTicker() {
        #expect(AssetClassType.detect(from: "ITUB3.SA") == .acoesBR)
        #expect(AssetClassType.detect(from: "KNRI11.SA") == .fiis)
        #expect(AssetClassType.detect(from: "AAPL") == .usStocks)
        #expect(AssetClassType.detect(from: "BTC") == .crypto)
    }

    // MARK: - StockQuote Decoding

    @Test func decodesStockQuote() throws {
        let json = """
        {
            "symbol": "ITUB3.SA",
            "name": "Itau Unibanco",
            "price": {"amount": "32.50", "currency": "BRL"},
            "currency": "BRL",
            "market_cap": {"amount": "320000000000", "currency": "BRL"}
        }
        """.data(using: .utf8)!

        let quote = try JSONDecoder().decode(StockQuoteDTO.self, from: json)
        #expect(quote.symbol == "ITUB3.SA")
        #expect(quote.price.decimalAmount == Decimal(string: "32.50"))
        #expect(quote.marketCap?.decimalAmount == Decimal(string: "320000000000"))
    }

    @Test func decodesStockQuoteWithNullMarketCap() throws {
        let json = """
        {
            "symbol": "BTC",
            "name": "Bitcoin",
            "price": {"amount": "350000", "currency": "BRL"},
            "currency": "BRL",
            "market_cap": null
        }
        """.data(using: .utf8)!

        let quote = try JSONDecoder().decode(StockQuoteDTO.self, from: json)
        #expect(quote.marketCap == nil)
    }

    // MARK: - Batch Quotes Decoding

    @Test func decodesBatchQuotes() throws {
        let json = """
        {
            "quotes": [
                {"symbol": "ITUB3.SA", "name": "Itau", "price": {"amount": "32.50", "currency": "BRL"}, "currency": "BRL", "dividend_yield": "7.96"},
                {"symbol": "AAPL", "name": "Apple", "price": {"amount": "180.00", "currency": "USD"}, "currency": "USD", "dividend_yield": null}
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BatchQuotesResponse.self, from: json)
        #expect(response.quotes.count == 2)
        #expect(response.quotes[0].price?.decimalAmount == Decimal(string: "32.50"))
        #expect(response.quotes[0].dividendYieldDecimal == Decimal(string: "7.96"))
        #expect(response.quotes[1].dividendYieldDecimal == nil)
    }

    @Test func decodesBatchQuoteWithNullPrice() throws {
        let json = """
        {
            "quotes": [
                {"symbol": "UNKNOWN", "name": null, "price": null, "currency": null, "dividend_yield": null}
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BatchQuotesResponse.self, from: json)
        #expect(response.quotes[0].price == nil)
        #expect(response.quotes[0].name == nil)
        #expect(response.quotes[0].dividendYieldDecimal == nil)
    }

    @Test func decodesBatchQuoteWithMissingDividendYieldKey() throws {
        let json = """
        {
            "quotes": [
                {"symbol": "BTC", "name": "Bitcoin", "price": {"amount": "350000", "currency": "BRL"}, "currency": "BRL"}
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(BatchQuotesResponse.self, from: json)
        #expect(response.quotes[0].dividendYieldDecimal == nil)
    }

    // MARK: - Mobile Dividend Decoding

    @Test func decodesMobileDividendWithPaymentDate() throws {
        let json = """
        {
            "symbol": "ITUB3.SA",
            "dividend_type": "JCP",
            "value": {"amount": "0.50", "currency": "BRL"},
            "ex_date": "2026-03-10",
            "payment_date": "2026-04-01"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(MobileDividendDTO.self, from: json)
        #expect(dto.symbol == "ITUB3.SA")
        #expect(dto.dividendType == "JCP")
        #expect(dto.value.decimalAmount == Decimal(string: "0.50"))
        #expect(dto.paymentDate == "2026-04-01")
    }

    @Test func decodesMobileDividendWithNullPaymentDate() throws {
        let json = """
        {
            "symbol": "BTLG11.SA",
            "dividend_type": "Dividend",
            "value": {"amount": "0.81", "currency": "BRL"},
            "ex_date": "2026-04-16",
            "payment_date": null
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(MobileDividendDTO.self, from: json)
        #expect(dto.paymentDate == nil)
    }

}
