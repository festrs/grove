import Foundation

/// In-memory holding draft used during onboarding before the user commits the
/// portfolio to SwiftData.
public struct PendingHolding: Identifiable, Sendable {
    public let id: UUID
    public var ticker: String
    public var displayName: String
    public var quantity: Decimal
    public var assetClass: AssetClassType
    public var status: HoldingStatus
    public var currentPrice: Decimal
    public var dividendYield: Decimal
    /// Backend-provided type hint from search (e.g. "REIT", "fund", "stock",
    /// "Common Stock"). Preserved across auto-classify so we don't lose the
    /// stronger signal in favor of ticker-only heuristics.
    public var apiType: String?

    public init(
        id: UUID = UUID(),
        ticker: String,
        displayName: String,
        quantity: Decimal,
        assetClass: AssetClassType,
        status: HoldingStatus,
        currentPrice: Decimal,
        dividendYield: Decimal,
        apiType: String? = nil
    ) {
        self.id = id
        self.ticker = ticker
        self.displayName = displayName
        self.quantity = quantity
        self.assetClass = assetClass
        self.status = status
        self.currentPrice = currentPrice
        self.dividendYield = dividendYield
        self.apiType = apiType
    }
}
