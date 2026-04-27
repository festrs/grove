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
    public let price: String?
    public let currency: String?
    public let change: String?
    public let sector: String?
    public let logo: String?

    public init(
        id: String,
        symbol: String,
        name: String? = nil,
        type: String? = nil,
        price: String? = nil,
        currency: String? = nil,
        change: String? = nil,
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
        guard let price else { return nil }
        return Decimal(string: price)
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

        if let price, let currency {
            let sym = currency == "BRL" ? "R$" : "$"
            parts.append("\(sym) \(price)")
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

    public init(symbol: String, name: String, price: MoneyDTO, currency: String, marketCap: MoneyDTO? = nil) {
        self.symbol = symbol
        self.name = name
        self.price = price
        self.currency = currency
        self.marketCap = marketCap
    }

    enum CodingKeys: String, CodingKey {
        case symbol, name, price, currency
        case marketCap = "market_cap"
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

    public init(symbol: String, name: String? = nil, price: MoneyDTO? = nil, currency: String? = nil) {
        self.symbol = symbol
        self.name = name
        self.price = price
        self.currency = currency
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

public nonisolated struct DividendSummaryDTO: Codable, Sendable {
    public let dividendPerShare: String

    public init(dividendPerShare: String) {
        self.dividendPerShare = dividendPerShare
    }

    enum CodingKeys: String, CodingKey {
        case dividendPerShare = "dividend_per_share"
    }

    public var decimalValue: Decimal {
        Decimal(string: dividendPerShare) ?? .zero
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
    public let quantity: Int
    public let currentPrice: Double
    public let assetClass: String
    public let totalValue: Double

    public init(ticker: String, displayName: String, quantity: Int, currentPrice: Double, assetClass: String, totalValue: Double) {
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
}
