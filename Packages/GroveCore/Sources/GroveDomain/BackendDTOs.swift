import Foundation

// MARK: - Common

public nonisolated struct MoneyDTO: Codable, Sendable {
    public let amount: String
    public let currency: String

    public init(amount: String, currency: String) {
        self.amount = amount
        self.currency = currency
    }

    public var decimalAmount: Decimal {
        Decimal(string: amount) ?? .zero
    }
}

// MARK: - Exchange Rate

public nonisolated struct BackendExchangeRateDTO: Codable, Sendable {
    public let pair: String
    public let rate: Double

    public init(pair: String, rate: Double) {
        self.pair = pair
        self.rate = rate
    }
}

// MARK: - Stock Search

public nonisolated struct StockSearchResultDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let symbol: String
    public let name: String?
    public let type: String?
    /// Backend returns price as a Money envelope (`{"amount": "42.25",
    /// "currency": "BRL"}`) when the search result was enriched with a
    /// quote, or omits the field for un-enriched US/ADR matches. Keep
    /// `currency` as a top-level convenience for the rare crypto path that
    /// returns a bare currency string with no price.
    public let price: MoneyDTO?
    public let currency: String?
    /// Percent change as the backend reports it (JSON number, e.g. `-0.35`).
    /// Decoded directly into `Decimal` via Swift's synthesized `Codable` — no
    /// `Double` round-trip — to keep the DTO consistent with the rest of the
    /// money-adjacent fields in the codebase.
    public let change: Decimal?
    public let sector: String?
    public let logo: String?

    public init(
        id: String,
        symbol: String,
        name: String? = nil,
        type: String? = nil,
        price: MoneyDTO? = nil,
        currency: String? = nil,
        change: Decimal? = nil,
        sector: String? = nil,
        logo: String? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.type = type
        self.price = price
        self.currency = currency
        self.change = change
        self.sector = sector
        self.logo = logo
    }

    public var priceDecimal: Decimal? {
        price?.decimalAmount
    }

    /// Currency tagged on the price envelope, falling back to the top-level
    /// `currency` field which is what the crypto search path emits.
    public var resolvedCurrency: String? {
        price?.currency ?? currency
    }

    /// Currency-aware price as a `Money` value. Prefer this over
    /// `priceDecimal` when downstream code might compare or convert against
    /// a target currency — the raw decimal alone is meaningless without
    /// knowing whether it's BRL or USD.
    public var priceMoney: Money? {
        guard let price else { return nil }
        guard let currency = Currency(rawValue: price.currency.lowercased()) else { return nil }
        return Money(amount: price.decimalAmount, currency: currency)
    }

    public var displaySymbol: String {
        symbol.replacingOccurrences(of: ".SA", with: "")
    }

    /// Inferred asset class from the API `type` field plus ticker heuristics.
    /// Single source of truth for badges and add-flow defaults.
    public var inferredAssetClass: AssetClassType? {
        AssetClassType.detect(from: symbol, apiType: type)
    }

    public var isCrypto: Bool {
        inferredAssetClass == .crypto
    }

    public var displayDescription: String {
        var parts: [String] = []

        if let name, name != symbol, name != displaySymbol {
            parts.append(name)
        }

        if let type = type?.lowercased() {
            switch type {
            case "fund": parts.append("FII")
            case "bdr": parts.append("BDR")
            case "stock": if symbol.hasSuffix(".SA") { parts.append("Acao BR") }
            default: break
            }
        }

        if let price {
            let sym = price.currency == "BRL" ? "R$" : "$"
            parts.append("\(sym) \(price.amount)")
        }

        return parts.joined(separator: " · ")
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Stock Quote

public nonisolated struct StockQuoteDTO: Codable, Sendable, Identifiable {
    public var id: String { symbol }
    public let symbol: String
    public let name: String
    public let price: MoneyDTO
    public let currency: String
    public let marketCap: MoneyDTO?
    /// Annual dividend yield as the backend reports it (already in percent).
    /// Optional because the field only appears on responses backed by a
    /// provider that exposes DY (yfinance for BR/US stocks); falls back to
    /// `nil` for fallback paths.
    public let dividendYield: String?

    public init(
        symbol: String,
        name: String,
        price: MoneyDTO,
        currency: String,
        marketCap: MoneyDTO? = nil,
        dividendYield: String? = nil
    ) {
        self.symbol = symbol
        self.name = name
        self.price = price
        self.currency = currency
        self.marketCap = marketCap
        self.dividendYield = dividendYield
    }

    enum CodingKeys: String, CodingKey {
        case symbol, name, price, currency
        case marketCap = "market_cap"
        case dividendYield = "dividend_yield"
    }

    public var dividendYieldDecimal: Decimal? {
        guard let dividendYield, !dividendYield.isEmpty else { return nil }
        return Decimal(string: dividendYield)
    }
}

// MARK: - Batch Quotes (mobile endpoint)

public nonisolated struct BatchQuotesResponse: Codable, Sendable {
    public let quotes: [BatchQuoteDTO]

    public init(quotes: [BatchQuoteDTO]) {
        self.quotes = quotes
    }
}

public nonisolated struct BatchQuoteDTO: Codable, Sendable, Identifiable {
    public var id: String { symbol }
    public let symbol: String
    public let name: String?
    public let price: MoneyDTO?
    public let currency: String?
    /// Annual dividend yield expressed in percent (e.g. `"7.96"` = 7.96%).
    /// Already-percent semantics — assign directly to `Holding.dividendYield`,
    /// do not multiply by 100.
    public let dividendYield: String?

    public init(
        symbol: String,
        name: String? = nil,
        price: MoneyDTO? = nil,
        currency: String? = nil,
        dividendYield: String? = nil
    ) {
        self.symbol = symbol
        self.name = name
        self.price = price
        self.currency = currency
        self.dividendYield = dividendYield
    }

    enum CodingKeys: String, CodingKey {
        case symbol, name, price, currency
        case dividendYield = "dividend_yield"
    }

    public var dividendYieldDecimal: Decimal? {
        guard let dividendYield, !dividendYield.isEmpty else { return nil }
        return Decimal(string: dividendYield)
    }
}

// MARK: - Mobile Dividends

public nonisolated struct MobileDividendDTO: Codable, Sendable, Identifiable {
    public var id: String { "\(symbol)-\(exDate)-\(dividendType)" }
    public let symbol: String
    public let dividendType: String
    public let value: MoneyDTO
    public let exDate: String
    public let paymentDate: String?

    public init(symbol: String, dividendType: String, value: MoneyDTO, exDate: String, paymentDate: String? = nil) {
        self.symbol = symbol
        self.dividendType = dividendType
        self.value = value
        self.exDate = exDate
        self.paymentDate = paymentDate
    }

    enum CodingKeys: String, CodingKey {
        case symbol
        case dividendType = "dividend_type"
        case value
        case exDate = "ex_date"
        case paymentDate = "payment_date"
    }
}

public nonisolated struct DividendRefreshResultDTO: Codable, Sendable {
    public let scraped: Int
    public let newRecords: Int
    public let failed: [String]

    public init(scraped: Int, newRecords: Int, failed: [String]) {
        self.scraped = scraped
        self.newRecords = newRecords
        self.failed = failed
    }

    enum CodingKeys: String, CodingKey {
        case scraped
        case newRecords = "new_records"
        case failed
    }
}

// MARK: - Price History

public nonisolated struct PriceHistoryPointDTO: Codable, Sendable {
    public let date: String
    public let price: MoneyDTO

    public init(date: String, price: MoneyDTO) {
        self.date = date
        self.price = price
    }
}

// MARK: - Import Portfolio

public nonisolated struct ImportParseResponse: Codable, Sendable {
    public let positions: [ImportedPosition]
    public let rawTextPreview: String?

    public init(positions: [ImportedPosition], rawTextPreview: String? = nil) {
        self.positions = positions
        self.rawTextPreview = rawTextPreview
    }

    enum CodingKeys: String, CodingKey {
        case positions
        case rawTextPreview = "raw_text_preview"
    }
}

public nonisolated struct ImportedPosition: Codable, Sendable, Identifiable {
    public var id: String { ticker }
    public let ticker: String
    public let displayName: String
    /// Backend serializes quantity as a JSON number (Pydantic `float`), so
    /// we decode it as Double — fractional quantities are valid (crypto,
    /// fractional shares). Integer-quantity rows display without the
    /// trailing `.0` via `displayQuantity`.
    public let quantity: Double
    public let currentPrice: Double
    public let assetClass: String
    public let totalValue: Double

    public init(ticker: String, displayName: String, quantity: Double, currentPrice: Double, assetClass: String, totalValue: Double) {
        self.ticker = ticker
        self.displayName = displayName
        self.quantity = quantity
        self.currentPrice = currentPrice
        self.assetClass = assetClass
        self.totalValue = totalValue
    }

    enum CodingKeys: String, CodingKey {
        case ticker
        case displayName = "display_name"
        case quantity
        case currentPrice = "current_price"
        case assetClass = "asset_class"
        case totalValue = "total_value"
    }

    public var assetClassType: AssetClassType {
        AssetClassType(rawValue: assetClass) ?? .acoesBR
    }

    public var displayTicker: String {
        ticker.replacingOccurrences(of: ".SA", with: "")
    }

    /// Renders quantity without a trailing `.0` for whole-share rows, while
    /// still showing fractional precision for crypto / fractional shares.
    public var displayQuantity: String {
        if quantity == quantity.rounded() {
            return String(Int(quantity))
        }
        return String(format: "%g", quantity)
    }
}
