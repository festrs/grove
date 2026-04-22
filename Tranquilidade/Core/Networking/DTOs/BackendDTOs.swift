import Foundation

// MARK: - Common

nonisolated struct MoneyDTO: Codable, Sendable {
    let amount: String
    let currency: String

    var decimalAmount: Decimal {
        Decimal(string: amount) ?? .zero
    }
}

// MARK: - Exchange Rate

nonisolated struct BackendExchangeRateDTO: Codable, Sendable {
    let pair: String
    let rate: Double
}

// MARK: - Stock Search

nonisolated struct StockSearchResultDTO: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let symbol: String
    let name: String?
    let type: String?
    let price: String?
    let currency: String?
    let change: String?
    let sector: String?
    let logo: String?

    var priceDecimal: Decimal? {
        guard let price else { return nil }
        return Decimal(string: price)
    }

    var displaySymbol: String {
        symbol.replacingOccurrences(of: ".SA", with: "")
    }

    var displayDescription: String {
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

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Stock Quote

nonisolated struct StockQuoteDTO: Codable, Sendable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let price: MoneyDTO
    let currency: String
    let marketCap: MoneyDTO?

    enum CodingKeys: String, CodingKey {
        case symbol, name, price, currency
        case marketCap = "market_cap"
    }
}

// MARK: - Batch Quotes (mobile endpoint)

nonisolated struct BatchQuotesResponse: Codable, Sendable {
    let quotes: [BatchQuoteDTO]
}

nonisolated struct BatchQuoteDTO: Codable, Sendable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String?
    let price: MoneyDTO?
    let currency: String?
}

// MARK: - Mobile Dividends

nonisolated struct MobileDividendDTO: Codable, Sendable, Identifiable {
    var id: String { "\(symbol)-\(exDate)-\(dividendType)" }
    let symbol: String
    let dividendType: String
    let value: MoneyDTO
    let exDate: String
    let paymentDate: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case dividendType = "dividend_type"
        case value
        case exDate = "ex_date"
        case paymentDate = "payment_date"
    }
}

nonisolated struct DividendSummaryDTO: Codable, Sendable {
    let dividendPerShare: String

    enum CodingKeys: String, CodingKey {
        case dividendPerShare = "dividend_per_share"
    }

    var decimalValue: Decimal {
        Decimal(string: dividendPerShare) ?? .zero
    }
}
