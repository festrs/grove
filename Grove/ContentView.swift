import SwiftUI
import SwiftData
import GroveDomain

/// App root. Routes between onboarding and the platform-appropriate
/// navigation shell, wires environment values, and kicks off initial sync
/// once onboarding is complete. Concrete navigation pieces live in
/// `Grove/Features/Navigation/`.
struct ContentView: View {
    let rateStore: RateStore

    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Query private var settings: [UserSettings]

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        Group {
            if settings.first?.hasCompletedOnboarding != true {
                OnboardingContainerView()
            } else {
                navigationShell
            }
        }
        .environment(\.displayCurrency, settings.first?.preferredCurrency ?? .brl)
        .overlay {
            #if DEBUG
            DebugFloatingButton()
            #endif
        }
        .task {
            ensureSettingsExist()
            await rateStore.refresh(using: backendService)
            guard settings.first?.hasCompletedOnboarding == true else { return }
            await syncService.syncAll(modelContext: modelContext, backendService: backendService)
        }
        .onChange(of: settings.first?.hasCompletedOnboarding) { _, completed in
            guard completed == true else { return }
            Task {
                await syncService.syncAll(modelContext: modelContext, backendService: backendService)
            }
        }
    }

    @ViewBuilder
    private var navigationShell: some View {
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

    private func ensureSettingsExist() {
        if settings.isEmpty {
            modelContext.insert(UserSettings())
        }
    }
}

#Preview {
    ContentView(rateStore: RateStore())
        .modelContainer(for: [
            Portfolio.self,
            Holding.self,
            DividendPayment.self,
            Contribution.self,
            UserSettings.self,
        ], inMemory: true)
}
