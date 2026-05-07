import SwiftUI
import GroveDomain
import GroveServices

/// Final read-only screen. Reuses the Freedom Number reveal language from
/// step 1 and adds three checkmarks summarizing what the user just set up.
/// The chrome's primary button switches to "Complete" automatically when
/// `currentStep == totalSteps - 1`.
struct RecapStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    private var freedomNumber: Money {
        viewModel.freedomNumber(displayCurrency: displayCurrency, rates: rates)
    }

    private var contribution: Money {
        Money(amount: viewModel.monthlyContributionCapacity, currency: viewModel.contributionCurrency)
    }

    private var classesWithTarget: Int {
        AssetClassType.allCases.reduce(0) { count, cls in
            count + ((viewModel.targetAllocations[cls] ?? 0) > 0 ? 1 : 0)
        }
    }

    private var aportarCount: Int {
        viewModel.pendingHoldings.filter { $0.status == .aportar }.count
    }

    private var holdingsRecapLine: String {
        let total = viewModel.pendingHoldings.count
        if total == 0 {
            return String(localized: "No assets yet — add them any time from Portfolio.")
        }
        if aportarCount == 0 {
            return String(localized: "\(total) asset\(total == 1 ? "" : "s") added · none marked Invest yet")
        }
        return String(localized: "\(total) asset\(total == 1 ? "" : "s") added · \(aportarCount) marked Invest")
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.tqAccentGreen)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: Theme.Spacing.xs) {
                Text("You're set")
                    .font(.system(size: Theme.FontSize.title2, weight: .bold))

                Text(verbatim: freedomNumber.formatted(in: displayCurrency, using: rates))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.tqAccentGreen)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("/ month, after tax — your Freedom Number")
                    .font(.caption)
                    .foregroundStyle(Color.tqSecondaryText)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                bullet(text: contributionLine)
                bullet(text: String(localized: "Strategy: \(classesWithTarget) of \(AssetClassType.allCases.count) classes targeted"))
                bullet(text: holdingsRecapLine)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Color.tqCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            .padding(.horizontal, Theme.Spacing.lg)

            Text(viewModel.pendingHoldings.isEmpty
                 ? String(localized: "Tap Complete to open your dashboard. Add tickers any time from Portfolio.")
                 : String(localized: "Tap Complete and head to Aportar — Grove will rank where to put your next contribution."))
                .font(.caption)
                .foregroundStyle(Color.tqSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contributionLine: String {
        if viewModel.monthlyContributionCapacity > 0 {
            let amount = contribution.formatted(in: displayCurrency, using: rates)
            return String(localized: "Investing \(amount)/month")
        }
        return String(localized: "Add a monthly contribution any time in Settings")
    }

    private func bullet(text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.tqAccentGreen)
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }
}

#Preview("With holdings") {
    let vm = OnboardingViewModel()
    vm.monthlyCostOfLiving = 8_000
    vm.fiIncomeMode = .lifestyle
    vm.monthlyContributionCapacity = 3_500
    vm.pendingHoldings = [
        PendingHolding(ticker: "ITUB3", displayName: "Itau", quantity: 0,
                       assetClass: .acoesBR, status: .aportar, currentPrice: 32, dividendYield: 6),
        PendingHolding(ticker: "BTLG11", displayName: "BTG Logistica", quantity: 0,
                       assetClass: .fiis, status: .aportar, currentPrice: 100, dividendYield: 8),
        PendingHolding(ticker: "AAPL", displayName: "Apple", quantity: 0,
                       assetClass: .usStocks, status: .estudo, currentPrice: 175, dividendYield: 0.5)
    ]
    return RecapStepView(viewModel: vm).preferredColorScheme(.dark)
}

#Preview("Skipped — no holdings") {
    let vm = OnboardingViewModel()
    vm.monthlyCostOfLiving = 8_000
    vm.fiIncomeMode = .essentials
    vm.monthlyContributionCapacity = 0
    return RecapStepView(viewModel: vm).preferredColorScheme(.dark)
}
