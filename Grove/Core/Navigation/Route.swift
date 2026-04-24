import Foundation
import SwiftData

enum Route: Hashable {
    case holdingDetail(PersistentIdentifier)
    case addHolding(AssetClassType?)
    case rebalancing
    case dividendCalendar
    case incomeHistory
    case settings
}
