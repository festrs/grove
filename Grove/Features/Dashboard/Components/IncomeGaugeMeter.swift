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

    /// `annualizedMonthlyNet × 12` — the run-rate framed as a yearly figure
    /// so the gauge's secondary line reads in the same units users think
    /// about FI in ("R$ 60k/year") instead of just per-month.
    private var annualizedYearlyNet: Money {
        Money(
            amount: projection.annualizedMonthlyNet.amount * 12,
            currency: projection.annualizedMonthlyNet.currency
        )
    }

    private var goalYearly: Money {
        Money(
            amount: projection.goalMonthly.amount * 12,
            currency: projection.goalMonthly.currency
        )
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

                // Progress ring with income inside.
                // Top number = trailing-12-month run-rate ÷ 12 (smoothed) —
                // the FI-relevant metric the ring tracks.
                // Bottom number = paid this calendar month (the actual paycheck).
                ZStack {
                    TQProgressRing(
                        progress: progressValue,
                        lineWidth: 16,
                        size: Theme.Layout.gaugeSize(for: sizeClass),
                        accentColor: goalReached ? Color.tqPositive : Color.tqAccentGreen
                    )

                    VStack(spacing: Theme.Spacing.xs) {
                        Text("\(projection.annualizedMonthlyNet.formatted(in: displayCurrency, using: rates))/mo")
                            .font(.system(size: Theme.FontSize.title2, weight: .bold))
                            .foregroundStyle(goalReached ? Color.tqPositive : .primary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text("AVG NET /MO (TTM)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.tqSecondaryText)
                            .tracking(0.4)

                        Divider()
                            .frame(width: 28)
                            .padding(.vertical, 2)

                        Text(projection.paidThisMonthNet.formatted(in: displayCurrency, using: rates))
                            .font(.system(size: Theme.FontSize.body, weight: .semibold))
                            .foregroundStyle(Color.tqSecondaryText)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text("PAID THIS MONTH")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.tqSecondaryText)
                            .tracking(0.4)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
                .padding(.top, Theme.Spacing.sm)

                // Progress percent and goal — framed yearly so users read
                // the gauge in the same units they think about FI in.
                VStack(spacing: Theme.Spacing.xs) {
                    Text("\(annualizedYearlyNet.formatted(in: displayCurrency, using: rates))/yr of \(goalYearly.formatted(in: displayCurrency, using: rates))/yr")
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(projection.progressPercent.formattedPercent(decimals: 2))
                        .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                        .foregroundStyle(Color.tqSecondaryText)

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
    // Spiky month: paid R$1,900 this month, but trailing-12m run-rate
    // is only R$1,300/mo. Ring tracks the run-rate.
    IncomeGaugeMeter(
        projection: IncomeProjection(
            currentMonthlyNet: Money(amount: 1_900, currency: .brl),
            currentMonthlyGross: Money(amount: 2_100, currency: .brl),
            paidThisMonthNet: Money(amount: 1_900, currency: .brl),
            annualizedMonthlyNet: Money(amount: 1_300, currency: .brl),
            goalMonthly: Money(amount: 10_000, currency: .brl),
            progressPercent: 13,
            estimatedMonthsToGoal: 96,
            estimatedYearsToGoal: 8
        )
    )
    .padding()
}

#Preview("Meta atingida") {
    IncomeGaugeMeter(
        projection: IncomeProjection(
            currentMonthlyNet: Money(amount: 10_500, currency: .brl),
            currentMonthlyGross: Money(amount: 13_000, currency: .brl),
            paidThisMonthNet: Money(amount: 12_300, currency: .brl),
            annualizedMonthlyNet: Money(amount: 10_400, currency: .brl),
            goalMonthly: Money(amount: 10_000, currency: .brl),
            progressPercent: 100,
            estimatedMonthsToGoal: 0,
            estimatedYearsToGoal: 0
        )
    )
    .padding()
}
