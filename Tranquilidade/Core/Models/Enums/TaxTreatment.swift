import Foundation

enum TaxTreatment: String, Codable, CaseIterable, Identifiable {
    /// FII dividends and BR stock dividends (currently exempt for PF)
    case exempt

    /// US stocks/REITs: 30% NRA withholding at source
    case nra30

    /// Crypto: 15% on gains above R$35k/month
    case crypto15

    /// Renda Fixa: IR regressivo (22.5% to 15% based on holding period)
    case irRegressivo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .exempt: "Isento"
        case .nra30: "30% NRA"
        case .crypto15: "15% Crypto"
        case .irRegressivo: "IR Regressivo"
        }
    }

    /// Net multiplier: after-tax fraction of gross income
    var netMultiplier: Decimal {
        switch self {
        case .exempt: 1.0
        case .nra30: 0.70
        case .crypto15: 0.85
        case .irRegressivo: 0.80 // ~average of 22.5%-15% table
        }
    }
}
