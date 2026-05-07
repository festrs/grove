import SwiftUI
import GroveDomain
import GroveServices

struct IncomeGaugeMeter: View {
    let projection: IncomeProjection
    var isInteractive: Bool = true
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    private var progressValue: Double {
        NSDecimalNumber(decimal: projection.progressPercent).doubleValue / 100.0
    }

    private var goalReached: Bool {
        projection.progressPercent >= 100
    }

    var body: some View {
        TQCard {
            VStack(spacing: Theme.Spacing.lg) {
                if isInteractive {
                    HStack {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.tqSecondaryText)
                    }
                    .padding(.bottom, -Theme.Spacing.md)
                }

                // Progress ring with income inside
                ZStack {
                    TQProgressRing(
                        progress: progressValue,
                        lineWidth: 16,
                        size: Theme.Layout.gaugeSize(for: sizeClass),
                        accentColor: goalReached ? Color.tqPositive : Color.tqAccentGreen
                    )

                    VStack(spacing: Theme.Spacing.xs) {
                        Text(projection.currentMonthlyNet.formatted(in: displayCurrency, using: rates))
                            .font(.system(size: Theme.FontSize.title2, weight: .bold))
                            .foregroundStyle(goalReached ? Color.tqPositive : .primary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text("/month")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundStyle(Color.tqSecondaryText)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
                .padding(.top, Theme.Spacing.sm)

                // Progress percent and goal
                VStack(spacing: Theme.Spacing.xs) {
                    Text("\(projection.progressPercent.formattedPercent(decimals: 2)) of \(projection.goalMonthly.formatted(in: displayCurrency, using: rates))")
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundStyle(.primary)

                    OnTrackPill(projection: projection)

                    // Estimated time or goal reached
                    if goalReached {
                        Label("Goal reached!", systemImage: "checkmark.seal.fill")
                            .font(.system(size: Theme.FontSize.body, weight: .semibold))
                            .foregroundStyle(Color.tqPositive)
                    } else if let years = projection.estimatedYearsToGoal {
                        let formatted = String(format: "%.1f", NSDecimalNumber(decimal: years).doubleValue)
                        Text("~\(formatted) years to financial freedom")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundStyle(Color.tqSecondaryText)
                    } else {
                        Text("Keep investing to reach your goal")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundStyle(Color.tqSecondaryText)
                    }
                }
                .padding(.bottom, Theme.Spacing.xs)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview("Em progresso") {
    IncomeGaugeMeter(
        projection: IncomeProjection(
            currentMonthlyNet: Money(amount: 5_840, currency: .brl),
            currentMonthlyGross: Money(amount: 7_200, currency: .brl),
            goalMonthly: Money(amount: 10_000, currency: .brl),
            progressPercent: 58.4,
            estimatedMonthsToGoal: 38,
            estimatedYearsToGoal: 3.2
        )
    )
    .padding()
}

#Preview("Meta atingida") {
    IncomeGaugeMeter(
        projection: IncomeProjection(
            currentMonthlyNet: Money(amount: 10_500, currency: .brl),
            currentMonthlyGross: Money(amount: 13_000, currency: .brl),
            goalMonthly: Money(amount: 10_000, currency: .brl),
            progressPercent: 100,
            estimatedMonthsToGoal: 0,
            estimatedYearsToGoal: 0
        )
    )
    .padding()
}
