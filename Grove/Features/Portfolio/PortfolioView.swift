import SwiftUI

/// Platform/size-class dispatcher. iPhone uses `CompactPortfolioView` with
/// a custom bottom-drawer search; iPad and macOS use `WidePortfolioView`
/// with the system `.searchable` toolbar field and a wide table layout.
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
