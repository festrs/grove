import SwiftUI

struct WelcomeStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // MARK: - Icon
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.tqAccentGreen)
                .symbolRenderingMode(.hierarchical)

            // MARK: - Title
            VStack(spacing: Theme.Spacing.md) {
                Text("How far are you from financial freedom?")
                    .font(.system(size: Theme.FontSize.title1, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Discover in 10 minutes. Add your assets and see your real passive income.")
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundStyle(Color.tqSecondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()

            // MARK: - CTA Button
            Button {
                withAnimation { viewModel.advance() }
            } label: {
                Text("Start")
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Color.tqAccentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

#Preview {
    WelcomeStepView(viewModel: OnboardingViewModel())
}
