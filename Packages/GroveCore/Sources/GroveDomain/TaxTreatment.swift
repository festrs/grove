import Foundation

public enum TaxTreatment: String, Codable, CaseIterable, Identifiable, Sendable {
    /// FII dividends and BR stock dividends (currently exempt for PF)
    case exempt

    /// US stocks/REITs: 30% NRA withholding at source
    case nra30

    /// Crypto: 15% on gains above R$35k/month
    case crypto15

    /// Renda Fixa: IR regressivo (22.5% to 15% based on holding period)
    case irRegressivo

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .exempt: "Exempt"
        case .nra30: "30% NRA"
        case .crypto15: "15% Crypto"
        case .irRegressivo: "Progressive Tax"
        }
    }

    /// Net multiplier: after-tax fraction of gross income
    public var netMultiplier: Decimal {
        switch self {
        case .exempt: 1.0
        case .nra30: 0.70
        case .crypto15: 0.85
        case .irRegressivo: 0.80 // ~average of 22.5%-15% table
        }
    }
}
