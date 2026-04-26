import SwiftUI

struct IncomeGaugeMeter: View {
    let projection: IncomeProjection
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var progressValue: Double {
        NSDecimalNumber(decimal: projection.progressPercent).doubleValue / 100.0
    }

    private var goalReached: Bool {
        projection.progressPercent >= 100
    }

    var body: some View {
        TQCard {
            VStack(spacing: Theme.Spacing.lg) {
                // Progress ring with income inside
                ZStack {
                    TQProgressRing(
                        progress: progressValue,
                        lineWidth: 16,
                        size: Theme.Layout.gaugeSize(for: sizeClass),
                        accentColor: goalReached ? Color.tqPositive : Color.tqAccentGreen
                    )

                    VStack(spacing: Theme.Spacing.xs) {
                        Text(projection.currentMonthlyNet.formattedBRL())
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
                    Text("\(projection.progressPercent.formattedPercent(decimals: 2)) of \(projection.goalMonthly.formattedBRL())")
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundStyle(.primary)

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
            currentMonthlyNet: 5_840,
            currentMonthlyGross: 7_200,
            goalMonthly: 10_000,
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
            currentMonthlyNet: 10_500,
            currentMonthlyGross: 13_000,
            goalMonthly: 10_000,
            progressPercent: 100,
            estimatedMonthsToGoal: 0,
            estimatedYearsToGoal: 0
        )
    )
    .padding()
}
