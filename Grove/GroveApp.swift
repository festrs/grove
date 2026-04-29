import SwiftUI
import SwiftData
import GroveDomain

@main
struct GroveApp: App {
    init() {
        UserDefaults.standard.register(defaults: [
            "notif_dividends": true,
            "notif_monthly": true,
            "notif_milestones": true,
            "notif_drift": false,
        ])
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Portfolio.self,
            Holding.self,
            DividendPayment.self,
            Contribution.self,
            UserSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If schema is corrupted, fall back to in-memory container so the app can launch
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()

    private let backendService = BackendService()
    @State private var syncService = SyncService()
    @State private var rateStore = RateStore()

    var body: some Scene {
        WindowGroup {
            ContentView(rateStore: rateStore)
                .preferredColorScheme(.dark)
                .environment(\.backendService, backendService)
                .environment(\.syncService, syncService)
                .environment(\.rates, rateStore)
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 600)
                #endif
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1100, height: 750)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Holding") {
                    NotificationCenter.default.post(name: .openAddHolding, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Sync") {
                    Task {
                        await syncService.syncAll(
                            modelContext: sharedModelContainer.mainContext,
                            backendService: backendService
                        )
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsSceneRoot()
                .preferredColorScheme(.dark)
                .environment(\.backendService, backendService)
                .environment(\.syncService, syncService)
                .environment(\.rates, rateStore)
                .modelContainer(sharedModelContainer)
                .frame(minWidth: 520, idealWidth: 560, minHeight: 540, idealHeight: 620)
        }
        #endif
    }
}

#if os(macOS)
extension Notification.Name {
    static let openAddHolding = Notification.Name("grove.openAddHolding")
}
#endif
