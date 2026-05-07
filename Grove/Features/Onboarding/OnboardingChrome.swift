import SwiftUI

/// Slim segmented capsule progress bar shared by all three onboarding
/// containers. The animation lives here so each container doesn't repeat it.
struct OnboardingProgressBar: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(0..<OnboardingViewModel.totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.tqAccentGreen : Color.tqFrozen)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.25), value: currentStep)
            }
        }
    }
}

/// Back / Next / Complete buttons. Two visual styles:
///
/// - `.fullWidth`: phone — both buttons stretch via `frame(maxWidth: .infinity)`.
/// - `.corners`: iPad / Mac — intrinsic-width buttons, paired with a `Spacer`
///   in the parent so they anchor to opposite corners.
struct OnboardingNavigationBar: View {
    @Bindable var viewModel: OnboardingViewModel
    let style: Style
    let onComplete: () -> Void

    enum Style {
        case fullWidth
        case corners
    }

    var body: some View {
        switch style {
        case .fullWidth:
            HStack(spacing: Theme.Spacing.md) {
                backButton
                primaryButton
            }
        case .corners:
            HStack(spacing: Theme.Spacing.sm) {
                backButton
                primaryButton
            }
        }
    }

    private var backButton: some View {
        Button {
            withAnimation { viewModel.goBack() }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .font(.body.weight(.medium))
            .foregroundStyle(Color.tqSecondaryText)
            .frame(maxWidth: style == .fullWidth ? .infinity : nil)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, style == .fullWidth ? 0 : Theme.Spacing.lg)
            .background(Color.tqCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }

    /// True when the user is on the optional holdings step with nothing
    /// added yet — the primary button morphs to "Skip — I'll add later"
    /// so the skip affordance is explicit instead of buried in the
    /// implicit "Next is fine when empty" path.
    private var isSkippableHoldingsStep: Bool {
        OnboardingViewModel.Step(rawValue: viewModel.currentStep) == .holdings
            && viewModel.pendingHoldings.isEmpty
    }

    @ViewBuilder
    private var primaryButton: some View {
        if viewModel.currentStep < OnboardingViewModel.totalSteps - 1 {
            Button {
                withAnimation { viewModel.advance() }
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(isSkippableHoldingsStep ? "Skip — I'll add later" : "Next")
                    Image(systemName: isSkippableHoldingsStep ? "arrow.right" : "chevron.right")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: style == .fullWidth ? .infinity : nil)
                .padding(.vertical, Theme.Spacing.md)
                .padding(.horizontal, style == .fullWidth ? 0 : Theme.Spacing.lg)
                .background(viewModel.canAdvance ? Color.tqAccentGreen : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canAdvance)
        } else {
            Button(action: onComplete) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Complete")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: style == .fullWidth ? .infinity : nil)
                .padding(.vertical, Theme.Spacing.md)
                .padding(.horizontal, style == .fullWidth ? 0 : Theme.Spacing.lg)
                .background(Color.tqAccentGreen)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Switches between the six concrete step views. Lives outside the
/// containers so the platform-specific chrome doesn't have to duplicate it.
struct OnboardingStepRouter: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        switch OnboardingViewModel.Step(rawValue: viewModel.currentStep) {
        case .welcome: WelcomeStepView(viewModel: viewModel)
        case .freedomPlan: FreedomPlanStepView(viewModel: viewModel)
        case .howGroveWorks: HowGroveWorksStepView()
        case .strategy: SetTargetsStepView(viewModel: viewModel)
        case .holdings: AddHoldingsStepView(viewModel: viewModel)
        case .recap: RecapStepView(viewModel: viewModel)
        case .none: EmptyView()
        }
    }
}
