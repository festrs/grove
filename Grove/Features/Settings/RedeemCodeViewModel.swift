import Foundation
import SwiftData
import GroveDomain

@Observable
@MainActor
final class RedeemCodeViewModel {
    var code: String = ""
    var isSubmitting: Bool = false
    var errorMessage: String?
    /// Flips to true once the backend confirms the code and the unlock has
    /// been written to UserSettings. The view watches this to dismiss the
    /// sheet / show a success state.
    var didUnlock: Bool = false

    var canSubmit: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    func redeem(modelContext: ModelContext, backendService: any BackendServiceProtocol) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let result = try await backendService.redeemCode(trimmed)
            guard result.valid, result.unlocksUnlimitedAssets else {
                errorMessage = String(localized: "Code not recognised. Double-check and try again.")
                return
            }
            let settings = try fetchOrCreateSettings(modelContext: modelContext)
            settings.unlimitedAssetsUnlocked = true
            try modelContext.save()
            didUnlock = true
        } catch {
            errorMessage = String(localized: "Could not verify the code. Check your connection and try again.")
        }
    }

    private func fetchOrCreateSettings(modelContext: ModelContext) throws -> UserSettings {
        if let existing = try modelContext.fetch(FetchDescriptor<UserSettings>()).first {
            return existing
        }
        let fresh = UserSettings()
        modelContext.insert(fresh)
        return fresh
    }
}
