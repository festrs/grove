import SwiftUI

/// One-shot prompt shown at the top of the Dashboard for users who finished
/// onboarding before the Freedom Plan flow existed (or who skipped it). Tap
/// opens `GoalSettingsView`, which marks the plan as completed on dismiss.
struct FreedomPlanBanner: View {
    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(Color.tqAccentGreen)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text("Build your Freedom Plan")
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Set the lifestyle, year, and contribution that anchor your projection.")
                    .font(.caption)
                    .foregroundStyle(Color.tqSecondaryText)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.tqSecondaryText)
        }
        .padding(Theme.Spacing.md)
        .background(Color.tqAccentGreen.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Color.tqAccentGreen.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }
}

#Preview {
    FreedomPlanBanner()
        .padding()
        .preferredColorScheme(.dark)
}
