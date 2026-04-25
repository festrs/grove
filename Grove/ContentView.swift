import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Query private var settings: [UserSettings]
    @Query private var holdings: [Holding]

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        Group {
            if settings.first?.hasCompletedOnboarding != true {
                OnboardingContainerView()
            } else {
                #if os(iOS)
                if horizontalSizeClass == .compact {
                    AppTabNavigation()
                } else {
                    AppSidebarNavigation()
                }
                #else
                AppSidebarNavigation()
                #endif
            }
        }
        .task {
            ensureSettingsExist()
            guard settings.first?.hasCompletedOnboarding == true else { return }
            await syncService.syncAll(
                modelContext: modelContext,
                backendService: backendService
            )
        }
        .onChange(of: settings.first?.hasCompletedOnboarding) { _, completed in
            guard completed == true else { return }
            Task {
                await syncService.syncAll(
                    modelContext: modelContext,
                    backendService: backendService
                )
            }
        }
    }

    private func ensureSettingsExist() {
        if settings.isEmpty {
            let newSettings = UserSettings()
            modelContext.insert(newSettings)
        }
    }
}

// MARK: - Navigation Item

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
        case .rebalancing: "Aportar"
        case .dividendCalendar: "Dividendos"
        case .incomeHistory: "Renda Passiva"
        case .settings: "Ajustes"
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

// MARK: - iPhone: Tab Navigation

struct AppTabNavigation: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.pie.fill") {
                DashboardView()
            }
            Tab("Portfolio", systemImage: "briefcase.fill") {
                PortfolioView()
            }
            Tab("Aportar", systemImage: "plus.circle.fill") {
                RebalancingView()
            }
            Tab("Ajustes", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(.tqAccentGreen)
    }
}

// MARK: - iPad / Mac: Sidebar Navigation

struct AppSidebarNavigation: View {
    @State private var selection: AppNavigationItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Visao Geral") {
                    sidebarLink(.dashboard)
                    sidebarLink(.portfolio)
                }

                Section("Investimentos") {
                    sidebarLink(.rebalancing)
                }

                Section("Renda") {
                    sidebarLink(.dividendCalendar)
                    sidebarLink(.incomeHistory)
                }

                Section {
                    sidebarLink(.settings)
                }
            }
            .navigationTitle("Grove")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack {
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
                case .settings:
                    SettingsView()
                case nil:
                    DashboardView()
                }
            }
        }
        .tint(.tqAccentGreen)
    }

    private func sidebarLink(_ item: AppNavigationItem) -> some View {
        Label(item.label, systemImage: item.icon)
            .tag(item)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Portfolio.self,
            Holding.self,
            DividendPayment.self,
            Contribution.self,
            UserSettings.self,
        ], inMemory: true)
}
