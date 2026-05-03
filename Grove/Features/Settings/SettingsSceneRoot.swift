import SwiftUI
import SwiftData
import GroveDomain

#if os(macOS)
/// Wraps `MacSettingsView` for the `Settings { ... }` scene so the user's
/// preferred display currency is loaded from `UserSettings` (the
/// `WindowGroup` can't share its environment across scenes). `\.rates` is
/// injected at the scene level by `GroveApp`.
struct SettingsSceneRoot: View {
    @Query private var settings: [UserSettings]

    var body: some View {
        MacSettingsView()
            .environment(\.displayCurrency, settings.first?.preferredCurrency ?? .brl)
    }
}
#endif
