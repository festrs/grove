import SwiftUI
import SwiftData
import GroveDomain

/// Root onboarding view. Owns the shared `OnboardingViewModel` and routes
/// to the platform-specific container — phone, iPad, or Mac (Catalyst).
/// Each container provides a distinct, native-feeling chrome; all three
/// reuse the same step views via `OnboardingStepRouter`.
struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        platformContainer
            .onAppear { viewModel.loadExistingAllocations(modelContext: modelContext) }
    }

    @ViewBuilder
    private var platformContainer: some View {
        #if os(macOS)
        OnboardingMacContainer(viewModel: viewModel)
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            OnboardingPadContainer(viewModel: viewModel)
        } else {
            OnboardingPhoneContainer(viewModel: viewModel)
        }
        #endif
    }
}

#Preview("Phone") {
    OnboardingPhoneContainer(viewModel: OnboardingViewModel())
        .modelContainer(for: [Portfolio.self, Holding.self, UserSettings.self], inMemory: true)
}

#Preview("iPad") {
    OnboardingPadContainer(viewModel: OnboardingViewModel())
        .modelContainer(for: [Portfolio.self, Holding.self, UserSettings.self], inMemory: true)
        .frame(width: 1180, height: 820)
}

#Preview("Mac") {
    OnboardingMacContainer(viewModel: OnboardingViewModel())
        .modelContainer(for: [Portfolio.self, Holding.self, UserSettings.self], inMemory: true)
        .frame(width: 1000, height: 800)
}
