import SwiftUI

enum AssetClassType: String, Codable, CaseIterable, Identifiable {
    case acoesBR
    case fiis
    case usStocks
    case reits
    case crypto
    case rendaFixa

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .acoesBR: "Acoes BR"
        case .fiis: "FIIs"
        case .usStocks: "Stocks US"
        case .reits: "REITs US"
        case .crypto: "Crypto"
        case .rendaFixa: "Renda Fixa"
        }
    }

    var icon: String {
        switch self {
        case .acoesBR: "chart.line.uptrend.xyaxis"
        case .fiis: "building.2"
        case .usStocks: "dollarsign.circle"
        case .reits: "house.fill"
        case .crypto: "bitcoinsign.circle"
        case .rendaFixa: "lock.shield"
        }
    }

    var color: Color {
        switch self {
        case .acoesBR: .blue
        case .fiis: .green
        case .usStocks: .purple
        case .reits: .orange
        case .crypto: .yellow
        case .rendaFixa: .teal
        }
    }

    var defaultCurrency: Currency {
        switch self {
        case .acoesBR, .fiis, .rendaFixa: .brl
        case .usStocks, .reits: .usd
        case .crypto: .usd
        }
    }

    var defaultTaxTreatment: TaxTreatment {
        switch self {
        case .acoesBR: .exempt
        case .fiis: .exempt
        case .usStocks: .nra30
        case .reits: .nra30
        case .crypto: .crypto15
        case .rendaFixa: .irRegressivo
        }
    }

    /// Auto-detect asset class from ticker string
    /// Detect asset class from ticker and optional API type field.
    static func detect(from ticker: String, apiType: String? = nil) -> AssetClassType? {
        // Strip exchange suffix (.SA for B3)
        let clean = ticker.uppercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ".SA", with: "")

        // Use API type when available (brapi: "fund" = FII, "stock" = BR equity, "bdr")
        if let apiType = apiType?.lowercased() {
            if apiType == "fund" { return .fiis }
            if apiType == "stock" { return .acoesBR }
            if apiType == "bdr" { return .usStocks }
        }

        // Crypto
        if ["BTC", "ETH", "SOL", "ADA", "DOT", "AVAX", "MATIC", "LINK", "UNI"].contains(clean) {
            return .crypto
        }

        // Brazilian tickers: end with digit(s), typically 1-2 digits
        if let lastChar = clean.last, lastChar.isNumber {
            let digits = String(clean.reversed().prefix(while: { $0.isNumber }).reversed())
            if digits == "11" {
                return .fiis
            }
            if ["3", "4", "5", "6"].contains(digits) {
                return .acoesBR
            }
        }

        // If none of the above matched, likely US stock
        if clean.allSatisfy({ $0.isLetter }) && clean.count <= 5 {
            return .usStocks
        }

        return nil
    }
}
