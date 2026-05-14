import SwiftUI

/// iPad + Mac sidebar shell. Owns navigation selection and the detail
/// switch.
struct AppSidebarNavigation: View {
    @State private var selection: AppNavigationItem? = .dashboard
    #if os(macOS)
    @State private var showingAddHolding = false
    #endif

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Overview") {
                    sidebarLink(.dashboard)
                    sidebarLink(.portfolio)
                }

                Section("Investments") {
                    sidebarLink(.rebalancing)
                }

                Section("Income") {
                    sidebarLink(.dividendCalendar)
                    sidebarLink(.incomeHistory)
                    sidebarLink(.incomeTrends)
                }

                #if !os(macOS)
                // iPadOS has no app-menu Settings, so keep it in the sidebar.
                // On macOS, Settings lives in the standard ⌘, Settings scene.
                Section {
                    sidebarLink(.settings)
                }
                #endif
            }
            .navigationTitle("Grove")
            .listStyle(.sidebar)
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
            #endif
        } detail: {
            NavigationStack {
                detailView
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.tqAccentGreen)
        #if os(macOS)
        // No window-level "+" toolbar button — the Portfolio screen exposes
        // search inline via `.searchable`. ⌘N still opens the dedicated
        // MacAddHoldingSheet from anywhere via the CommandGroup in GroveApp.
        .sheet(isPresented: $showingAddHolding) {
            MacAddHoldingSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAddHolding)) { _ in
            showingAddHolding = true
        }
        #endif
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .dashboard:
            DashboardView()
        case .portfolio:
            PortfolioView()
        case .rebalancing:
            RebalancingView()
        case .dividendCalendar:
            DividendCalendarView()
        case .incomeHistory:
            IncomeHistoryView()
        case .incomeTrends:
            IncomeTrendsView()
        case .settings:
            #if os(macOS)
            DashboardView()
            #else
            SettingsView()
            #endif
        case nil:
            DashboardView()
        }
    }

    private func sidebarLink(_ item: AppNavigationItem) -> some View {
        Label(item.label, systemImage: item.icon)
            .tag(item)
    }
}
