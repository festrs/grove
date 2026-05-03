import SwiftUI

/// iPhone-only tab bar. iPad/Mac use `AppSidebarNavigation` instead.
struct AppTabNavigation: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.pie.fill") {
                DashboardView()
            }
            Tab("Portfolio", systemImage: "briefcase.fill") {
                PortfolioView()
            }
            Tab("Invest", systemImage: "plus.circle.fill") {
                RebalancingView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(.tqAccentGreen)
    }
}
