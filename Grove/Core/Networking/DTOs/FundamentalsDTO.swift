import Foundation
import SwiftUI
import GroveDomain

nonisolated struct FundamentalsDTO: Codable, Sendable {
    let symbol: String
    let ipoYears: Int?
    let ipoRating: String?
    let epsGrowthPct: Double?
    let epsRating: String?
    let currentNetDebtEbitda: Double?
    let highDebtYearsPct: Double?
    let debtRating: String?
    let profitableYearsPct: Double?
    let profitRating: String?
    let compositeScore: Double?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case ipoYears = "ipo_years"
        case ipoRating = "ipo_rating"
        case epsGrowthPct = "eps_growth_pct"
        case epsRating = "eps_rating"
        case currentNetDebtEbitda = "current_net_debt_ebitda"
        case highDebtYearsPct = "high_debt_years_pct"
        case debtRating = "debt_rating"
        case profitableYearsPct = "profitable_years_pct"
        case profitRating = "profit_rating"
        case compositeScore = "composite_score"
        case updatedAt = "updated_at"
    }

    /// Map backend rating strings ("green"/"yellow"/"red") to SwiftUI colors.
    static func ratingColor(_ rating: String?) -> Color {
        switch rating?.lowercased() {
        case "green": .tqPositive
        case "yellow": .tqWarning
        case "red": .tqNegative
        default: .secondary
        }
    }

    var scoreColor: Color { Self.ratingColor(compositeScore.map { $0 >= 60 ? "green" : $0 >= 40 ? "yellow" : "red" }) }
    var profitColor: Color { Self.ratingColor(profitRating) }
    var epsColor: Color { Self.ratingColor(epsRating) }
    var debtColor: Color { Self.ratingColor(debtRating) }
    var ipoColor: Color { Self.ratingColor(ipoRating) }
}
