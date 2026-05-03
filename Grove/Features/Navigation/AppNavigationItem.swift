import Foundation

/// Top-level destination shared by `AppSidebarNavigation` (iPad/Mac) and
/// the detail switch. iPhone uses `TabView` directly so it doesn't need
/// this enum.
enum AppNavigationItem: String, Hashable, CaseIterable, Identifiable {
    case dashboard
    case portfolio
    case rebalancing
    case dividendCalendar
    case incomeHistory
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: "Dashboard"
        case .portfolio: "Portfolio"
        case .rebalancing: "Invest"
        case .dividendCalendar: "Dividends"
        case .incomeHistory: "Passive Income"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "chart.pie.fill"
        case .portfolio: "briefcase.fill"
        case .rebalancing: "plus.circle.fill"
        case .dividendCalendar: "calendar"
        case .incomeHistory: "chart.bar.fill"
        case .settings: "gearshape.fill"
        }
    }
}
