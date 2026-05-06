import SwiftUI
import SwiftData
import GroveDomain

/// Mac (Catalyst) onboarding chrome. Centered fixed-size card on a tinted
/// backdrop — the same idiom used by Xcode's "Welcome", System Settings
/// setup panes, and Numbers/Pages template chooser. Compact "Step X of N"
/// caption + slim progress bar in the card header, step content in the
/// middle, footer with intrinsic-width Back / Next anchored to the right.
struct OnboardingMacContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Bindable var viewModel: OnboardingViewModel

    private let cardWidth: CGFloat = 720
    private let cardHeight: CGFloat = 640

    var body: some View {
        ZStack {
            Color.tqBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()

                OnboardingStepRouter(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.xs)
                        .transition(.opacity)
                }

                Divider()
                footer
            }
            .frame(maxWidth: cardWidth, maxHeight: cardHeight)
            .background(Color.tqCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 8)
            .padding(Theme.Spacing.xl)
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("Step \(viewModel.currentStep + 1) of \(OnboardingViewModel.totalSteps)")
                    .font(.caption)
                    .foregroundStyle(Color.tqSecondaryText)
                Spacer()
            }
            OnboardingProgressBar(currentStep: viewModel.currentStep)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Spacer()
            if viewModel.currentStep > 0 {
                OnboardingNavigationBar(
                    viewModel: viewModel,
                    style: .corners,
                    onComplete: complete
                )
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .frame(minHeight: 56)
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
