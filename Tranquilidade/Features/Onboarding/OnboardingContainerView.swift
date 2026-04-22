import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Progress Indicator
            progressBar
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)

            // MARK: - Step Content
            TabView(selection: $viewModel.currentStep) {
                WelcomeStepView(viewModel: viewModel)
                    .tag(0)

                AddHoldingsStepView(viewModel: viewModel)
                    .tag(1)

                ClassificationStepView(viewModel: viewModel)
                    .tag(2)

                SetTargetsStepView(viewModel: viewModel)
                    .tag(3)

                SetStatusStepView(viewModel: viewModel)
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
            .scrollDisabled(true) // Disable swipe — controlled navigation only

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
                    Text("Voltar")
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
                        Text("Proximo")
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
                    viewModel.completeOnboarding(modelContext: modelContext)
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Concluir")
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
