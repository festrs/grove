import SwiftUI
import SwiftData
import GroveDomain

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Progress Indicator
            progressBar
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)

            // MARK: - Step Content
            Group {
                switch viewModel.currentStep {
                case 0: WelcomeStepView(viewModel: viewModel)
                case 1: AddHoldingsStepView(viewModel: viewModel)
                case 2: ClassificationStepView(viewModel: viewModel)
                case 3: SetTargetsStepView(viewModel: viewModel)
                case 4: SetStatusStepView(viewModel: viewModel)
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)

            // MARK: - Error Message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .transition(.opacity)
            }

            // MARK: - Navigation Buttons
            if viewModel.currentStep > 0 {
                navigationButtons
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
            }
        }
        .background(Color.tqBackground)
        .onAppear { viewModel.loadExistingAllocations(modelContext: modelContext) }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(0..<OnboardingViewModel.totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= viewModel.currentStep ? Color.tqAccentGreen : Color.tqFrozen)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.25), value: viewModel.currentStep)
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button {
                withAnimation { viewModel.goBack() }
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.body.weight(.medium))
                .foregroundStyle(Color.tqSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Color.tqCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            }

            if viewModel.currentStep < OnboardingViewModel.totalSteps - 1 {
                Button {
                    withAnimation { viewModel.advance() }
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(viewModel.canAdvance ? Color.tqAccentGreen : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                }
                .disabled(!viewModel.canAdvance)
            } else {
                Button {
                    viewModel.completeOnboarding(modelContext: modelContext, backendService: backendService)
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Color.tqAccentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                }
            }
        }
    }
}

#Preview {
    OnboardingContainerView()
        .modelContainer(for: [Portfolio.self, Holding.self, UserSettings.self], inMemory: true)
}
