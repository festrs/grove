import SwiftUI
import SwiftData

@main
struct GroveApp: App {
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
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private let backendService = BackendService()
    @State private var syncService = SyncService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .environment(\.backendService, backendService)
                .environment(\.syncService, syncService)
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 600)
                #endif
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1100, height: 750)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Sincronizar") {
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
    }
}
