import SwiftUI
import SwiftData
import GroveDomain

/// iPad-only onboarding chrome. Full-screen — no floating card. A wide
/// progress bar pinned at the top, the step content fills the available
/// canvas, and a footer row places Back/Next at the bottom corners with
/// intrinsic-width buttons (the pattern used by Apple's first-run setup
/// flows on iPad: Health, Apple TV, Subscribe sheets).
struct OnboardingPadContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            Color.tqBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.lg)

                OnboardingStepRouter(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.bottom, Theme.Spacing.xs)
                        .transition(.opacity)
                }

                Divider()
                footer
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.lg)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Step \(viewModel.currentStep + 1) of \(OnboardingViewModel.totalSteps)")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.tqSecondaryText)
            OnboardingProgressBar(currentStep: viewModel.currentStep)
        }
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.md) {
            if viewModel.currentStep > 0 {
                OnboardingNavigationBar(
                    viewModel: viewModel,
                    style: .corners,
                    onComplete: complete
                )
            } else {
                Spacer()
            }
        }
        .frame(minHeight: 44)
    }

    private func complete() {
        viewModel.completeOnboarding(modelContext: modelContext, backendService: backendService)
    }
}
