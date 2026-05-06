import SwiftUI
import SwiftData
import GroveDomain

/// iPhone-only onboarding chrome. Full-screen, edge-to-edge, with a slim
/// progress bar at the top and full-width Back/Next buttons at the bottom —
/// the standard iOS setup-flow shape.
struct OnboardingPhoneContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(currentStep: viewModel.currentStep)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)

            OnboardingStepRouter(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .transition(.opacity)
            }

            if viewModel.currentStep > 0 {
                OnboardingNavigationBar(
                    viewModel: viewModel,
                    style: .fullWidth,
                    onComplete: complete
                )
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
            }
        }
        .background(Color.tqBackground)
    }

    private func complete() {
        viewModel.completeOnboarding(
            modelContext: modelContext,
            backendService: backendService,
            displayCurrency: displayCurrency,
            rates: rates
        )
    }
}
