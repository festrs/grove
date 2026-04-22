import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Query private var settings: [UserSettings]
    @Query private var holdings: [Holding]

    var body: some View {
        Group {
            if holdings.isEmpty && settings.first?.hasCompletedOnboarding != true {
                OnboardingContainerView()
            } else {
                MainTabView()
            }
        }
        .task {
            ensureSettingsExist()
            await syncService.syncAll(
                modelContext: modelContext,
                backendService: backendService
            )
        }
    }

    private func ensureSettingsExist() {
        if settings.isEmpty {
            let newSettings = UserSettings()
            modelContext.insert(newSettings)
        }
    }
}

struct MainTabView: View {
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
