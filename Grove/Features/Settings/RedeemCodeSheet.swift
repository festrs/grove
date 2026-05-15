import SwiftUI
import GroveDomain

/// Modal that hosts `RedeemCodeViewModel` so any feature (Settings,
/// Onboarding) can ask the user for an unlock code. Dismisses itself
/// on success and fires `onUnlock` so the host can react (e.g. update
/// its own copy of the unlock flag for views that don't watch
/// `UserSettings` directly).
struct RedeemCodeSheet: View {
    var onUnlock: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = RedeemCodeViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter code", text: $viewModel.code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .disabled(viewModel.isSubmitting)
                } footer: {
                    Text("Codes unlock features in Grove. If you have one, paste it here.")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(Color.tqNegative)
                    }
                }
            }
            .navigationTitle("Redeem code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Redeem") {
                        Task {
                            await viewModel.redeem(modelContext: modelContext, backendService: backendService)
                            if viewModel.didUnlock {
                                onUnlock()
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
            .overlay {
                if viewModel.isSubmitting {
                    ProgressView()
                }
            }
        }
    }
}
