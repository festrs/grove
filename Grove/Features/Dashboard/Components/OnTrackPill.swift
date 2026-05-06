import SwiftUI
import GroveDomain
import GroveServices

/// Pure renderer for `IncomeProjection.targetYearStatus`. All classification
/// logic lives on the model — this view only maps semantic states to color,
/// icon, and copy.
struct OnTrackPill: View {
    let projection: IncomeProjection

    var body: some View {
        switch projection.targetYearStatus {
        case .hidden:
            EmptyView()
        case .onTrack(let year):
            pill(
                tone: .positive,
                icon: "checkmark.seal.fill",
                text: Text("On track for \(year)")
            )
        case .tight(let year, let yearsShort):
            pill(
                tone: .warning,
                icon: "exclamationmark.triangle.fill",
                text: yearsShort == 1
                    ? Text("\(year) is tight — ~1 year short")
                    : Text("\(year) is tight — ~\(yearsShort) years short")
            )
        case .far(let year, let yearsShort):
            pill(
                tone: .negative,
                icon: "clock.badge.exclamationmark.fill",
                text: Text("\(year) looks far — ~\(yearsShort) years short")
            )
        case .needContribution(let year):
            pill(
                tone: .neutral,
                icon: "arrow.up.circle.fill",
                text: Text("Need more contribution to reach \(year)")
            )
        }
    }

    private enum Tone {
        case positive, warning, negative, neutral

        var color: Color {
            switch self {
            case .positive: Color.tqPositive
            case .warning: Color.orange
            case .negative: Color.tqNegative
            case .neutral: Color.tqSecondaryText
            }
        }
    }

    private func pill(tone: Tone, icon: String, text: Text) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            text
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 4)
        .background(tone.color.opacity(0.15))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(tone.color.opacity(0.35), lineWidth: 1))
    }
}

#Preview("On track") {
    OnTrackPill(projection: IncomeProjection(
        currentMonthlyNet: Money(amount: 6_000, currency: .brl),
        currentMonthlyGross: Money(amount: 7_500, currency: .brl),
        goalMonthly: Money(amount: 12_000, currency: .brl),
        progressPercent: 50,
        estimatedMonthsToGoal: 24,
        estimatedYearsToGoal: 2,
        targetFIYear: 2046,
        monthsRemainingToTargetYear: 240,
        onTrackForTargetYear: true
    ))
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Tight") {
    OnTrackPill(projection: IncomeProjection(
        currentMonthlyNet: Money(amount: 6_000, currency: .brl),
        currentMonthlyGross: Money(amount: 7_500, currency: .brl),
        goalMonthly: Money(amount: 12_000, currency: .brl),
        progressPercent: 50,
        estimatedMonthsToGoal: 60,
        estimatedYearsToGoal: 5,
        targetFIYear: 2029,
        monthsRemainingToTargetYear: 36,
        onTrackForTargetYear: false
    ))
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Far") {
    OnTrackPill(projection: IncomeProjection(
        currentMonthlyNet: Money(amount: 6_000, currency: .brl),
        currentMonthlyGross: Money(amount: 7_500, currency: .brl),
        goalMonthly: Money(amount: 12_000, currency: .brl),
        progressPercent: 50,
        estimatedMonthsToGoal: 240,
        estimatedYearsToGoal: 20,
        targetFIYear: 2030,
        monthsRemainingToTargetYear: 60,
        onTrackForTargetYear: false
    ))
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Need contribution") {
    OnTrackPill(projection: IncomeProjection(
        currentMonthlyNet: Money(amount: 0, currency: .brl),
        currentMonthlyGross: Money(amount: 0, currency: .brl),
        goalMonthly: Money(amount: 30_000, currency: .brl),
        progressPercent: 0,
        estimatedMonthsToGoal: nil,
        estimatedYearsToGoal: nil,
        targetFIYear: 2046,
        monthsRemainingToTargetYear: 240,
        onTrackForTargetYear: nil
    ))
    .padding()
    .preferredColorScheme(.dark)
}
