import SwiftUI
import SwiftData
import GroveDomain

/// Platform/size-class dispatcher.
///
/// - **iPhone (compact):** `CompactPortfolioView` with the bottom-drawer search.
/// - **iPad / macOS:** `WidePortfolioView` with the split-view sidebar.
struct PortfolioView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        #if os(macOS)
        WidePortfolioView()
        #else
        if sizeClass == .compact {
            CompactPortfolioView()
        } else {
            WidePortfolioView()
        }
        #endif
    }
}
