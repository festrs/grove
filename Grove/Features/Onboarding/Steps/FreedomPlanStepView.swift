import SwiftUI
import GroveDomain
import GroveServices

/// Step 1 of onboarding — five sub-screens that capture the user's Freedom
/// Plan and reveal their personal Freedom Number. Sub-step navigation is
/// driven by `OnboardingViewModel.advance/goBack`, which keeps the global
/// Back/Next chrome below in sync.
struct FreedomPlanStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.freedomPlanSubStep {
            case 0: CostSubStep(viewModel: viewModel, displayCurrency: displayCurrency)
            case 1: TargetYearSubStep(viewModel: viewModel)
            case 2: IncomeModeSubStep(viewModel: viewModel)
            case 3: ContributionSubStep(viewModel: viewModel, displayCurrency: displayCurrency)
            case 4: RevealSubStep(
                viewModel: viewModel,
                displayCurrency: displayCurrency,
                rates: rates
            )
            default: EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Theme.Spacing.lg)
        .animation(.easeInOut(duration: 0.25), value: viewModel.freedomPlanSubStep)
    }
}

// MARK: - Sub-step 0: Cost of living today

private struct CostSubStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let displayCurrency: Currency

    var body: some View {
        SubStepScaffold(
            icon: "house.fill",
            title: "Cost of living today",
            subtitle: "Your total monthly spend — rent or mortgage, food, transport, everything. Round numbers are fine."
        ) {
            TQCurrencyField(
                title: "Monthly expenses",
                currency: displayCurrency,
                value: $viewModel.monthlyCostOfLiving
            )
            .onAppear {
                viewModel.costOfLivingCurrency = displayCurrency
            }
            .onChange(of: displayCurrency) { _, new in
                viewModel.costOfLivingCurrency = new
            }
        }
    }
}

// MARK: - Sub-step 1: Target FI year

private struct TargetYearSubStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var range: ClosedRange<Int> {
        let now = Calendar.current.component(.year, from: .now)
        return now...(now + 50)
    }

    var body: some View {
        SubStepScaffold(
            icon: "calendar",
            title: "When do you want to be free?",
            subtitle: "You can change this any time as your plans evolve."
        ) {
            VStack(spacing: Theme.Spacing.md) {
                Text(verbatim: "\(viewModel.targetFIYear)")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(Color.tqAccentGreen)
                    .monospacedDigit()

                Stepper(
                    value: $viewModel.targetFIYear,
                    in: range,
                    step: 1
                ) {
                    let yearsOut = viewModel.targetFIYear - Calendar.current.component(.year, from: .now)
                    Text(yearsOut == 1 ? "in 1 year" : "in \(yearsOut) years")
                        .font(.callout)
                        .foregroundStyle(Color.tqSecondaryText)
                }
                .padding(Theme.Spacing.md)
                .background(Color.tqCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            }
        }
    }
}

// MARK: - Sub-step 2: Income mode

private struct IncomeModeSubStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        SubStepScaffold(
            icon: "dial.medium",
            title: "What kind of free?",
            subtitle: "Pick the lifestyle that matches your goal. We use this to size your target income."
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ModeCard(
                    mode: .essentials,
                    title: "Cover today's life · 1×",
                    detail: "Hit your current monthly spend exactly. No headroom for inflation or upgrades.",
                    selected: viewModel.fiIncomeMode == .essentials
                ) { viewModel.fiIncomeMode = .essentials }

                ModeCard(
                    mode: .lifestyle,
                    title: "Comfortable · 1.5×",
                    detail: "50% headroom on top of today's spend — for inflation, lifestyle creep, and the occasional splurge.",
                    selected: viewModel.fiIncomeMode == .lifestyle
                ) { viewModel.fiIncomeMode = .lifestyle }

                ModeCard(
                    mode: .lifestylePlusBuffer,
                    title: "Comfortable + buffer · 2×",
                    detail: "Double today's spend. Generous cushion against bad markets and surprises.",
                    selected: viewModel.fiIncomeMode == .lifestylePlusBuffer
                ) { viewModel.fiIncomeMode = .lifestylePlusBuffer }
            }
        }
    }
}

private struct ModeCard: View {
    let mode: FIIncomeMode
    let title: String
    let detail: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? Color.tqAccentGreen : Color.tqSecondaryText)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.tqSecondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.md)
            .background(Color.tqCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(selected ? Color.tqAccentGreen : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sub-step 3: Monthly contribution capacity

private struct ContributionSubStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let displayCurrency: Currency

    var body: some View {
        SubStepScaffold(
            icon: "arrow.up.circle.fill",
            title: "What can you invest each month?",
            subtitle: "Be honest — the projection only matters if it reflects reality. Zero is fine for now."
        ) {
            TQCurrencyField(
                title: "Monthly contribution",
                currency: displayCurrency,
                value: $viewModel.monthlyContributionCapacity
            )
            .onAppear {
                viewModel.contributionCurrency = displayCurrency
            }
            .onChange(of: displayCurrency) { _, new in
                viewModel.contributionCurrency = new
            }
        }
    }
}

// MARK: - Sub-step 4: Reveal

private struct RevealSubStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let displayCurrency: Currency
    let rates: any ExchangeRates

    private var freedomNumber: Money {
        viewModel.freedomNumber(displayCurrency: displayCurrency, rates: rates)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(Color.tqAccentGreen)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: Theme.Spacing.xs) {
                Text("Your Freedom Number")
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundStyle(Color.tqSecondaryText)

                Text(verbatim: freedomNumber.formatted(in: displayCurrency, using: rates))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.tqAccentGreen)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("/ month, after tax")
                    .font(.caption)
                    .foregroundStyle(Color.tqSecondaryText)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                bullet(Text("Targeting \(viewModel.targetFIYear) (\(yearsOut) years out)"))
                bullet(Text("Lifestyle: ") + modeLabel)
                if viewModel.monthlyContributionCapacity > 0 {
                    let amount = monthlyContribution.formatted(in: displayCurrency, using: rates)
                    bullet(Text("Investing \(amount)/month"))
                } else {
                    bullet(Text("Add a monthly contribution later in Settings to project a date."))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Color.tqCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))

            Text("Next: add your assets so we can show how close you already are.")
                .font(.caption)
                .foregroundStyle(Color.tqSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.md)

            Spacer()
        }
    }

    private var monthlyContribution: Money {
        Money(amount: viewModel.monthlyContributionCapacity, currency: viewModel.contributionCurrency)
    }

    private var yearsOut: Int {
        max(0, viewModel.targetFIYear - Calendar.current.component(.year, from: .now))
    }

    private var modeLabel: Text {
        switch viewModel.fiIncomeMode {
        case .essentials: Text("cover today's life (1×)")
        case .lifestyle: Text("comfortable (1.5×)")
        case .lifestylePlusBuffer: Text("comfortable + buffer (2×)")
        }
    }

    private func bullet(_ text: Text) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.tqAccentGreen)
            text
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Scaffold

private struct SubStepScaffold<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(Color.tqAccentGreen)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(.system(size: Theme.FontSize.title2, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(Color.tqSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.md)
            }

            content
                .padding(.horizontal, Theme.Spacing.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Cost") {
    let vm = OnboardingViewModel()
    vm.currentStep = OnboardingViewModel.Step.freedomPlan.rawValue
    vm.freedomPlanSubStep = 0
    return FreedomPlanStepView(viewModel: vm).preferredColorScheme(.dark)
}

#Preview("Reveal") {
    let vm = OnboardingViewModel()
    vm.currentStep = OnboardingViewModel.Step.freedomPlan.rawValue
    vm.freedomPlanSubStep = 4
    vm.monthlyCostOfLiving = 8_000
    vm.fiIncomeMode = .lifestyle
    vm.monthlyContributionCapacity = 4_000
    return FreedomPlanStepView(viewModel: vm).preferredColorScheme(.dark)
}
