import SwiftUI
import SwiftData
import GroveDomain

/// Platform/size-class dispatcher.
///
/// - **iPhone (compact):** `CompactPortfolioView` with the bottom-drawer
///   search. Unchanged.
/// - **iPad / macOS:** if the user has more than one portfolio, lands on
///   `PortfoliosOverviewView` first; tapping a portfolio drills into the
///   `WidePortfolioView` scoped to that portfolio. With a single portfolio
///   (or none yet), goes straight to the wide view as before.
struct PortfolioView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @State private var pinnedPortfolioID: PersistentIdentifier?

    var body: some View {
        #if os(macOS)
        wideRoot
        #else
        if sizeClass == .compact {
            CompactPortfolioView()
        } else {
            wideRoot
        }
        #endif
    }

    @ViewBuilder
    private var wideRoot: some View {
        if portfolios.count > 1, pinnedPortfolioID == nil {
            PortfoliosOverviewView(onSelect: { id in
                pinnedPortfolioID = id
            })
        } else {
            WidePortfolioView(
                initialPortfolioID: pinnedPortfolioID,
                onBackToOverview: portfolios.count > 1
                    ? { pinnedPortfolioID = nil }
                    : nil
            )
        }
    }
}
