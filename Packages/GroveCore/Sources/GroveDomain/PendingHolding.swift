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
    /// User-entered buy price for the bootstrap contribution. When nil, the
    /// repository falls back to `currentPrice` at completion time.
    public var averagePrice: Decimal?
    /// User-entered purchase date. When nil, the repository uses `.now`.
    public var purchaseDate: Date?
    /// Within-class priority for the rebalancing engine (1–5, default 5).
    /// Only meaningful when ≥ 2 holdings share the same class; the engine
    /// uses it to break ties for monthly buy ranking.
    public var targetPercent: Decimal

    public init(
        id: UUID = UUID(),
        ticker: String,
        displayName: String,
        quantity: Decimal,
        assetClass: AssetClassType,
        status: HoldingStatus,
        currentPrice: Decimal,
        dividendYield: Decimal,
        apiType: String? = nil,
        averagePrice: Decimal? = nil,
        purchaseDate: Date? = nil,
        targetPercent: Decimal = 5
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
        self.averagePrice = averagePrice
        self.purchaseDate = purchaseDate
        self.targetPercent = targetPercent
    }
}
