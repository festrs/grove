import SwiftUI
import GroveDomain

/// Bridge screen between the Freedom Plan reveal and the Strategy step.
/// This is the only screen that does pure concept teaching — the rest of
/// onboarding is goal-capture or action. Three cards introduce the engine
/// that turns the user's Freedom Number into monthly buy advice.
struct HowGroveWorksStepView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .regular {
                regularBody
            } else {
                compactBody
            }
        }
    }

    // MARK: - Compact

    private var compactBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                StrategyConceptCard()
                PipelineConceptCard()
                AportarListConceptCard()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    // MARK: - Regular

    private var regularBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            header
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                StrategyConceptCard().frame(maxWidth: .infinity, alignment: .topLeading)
                PipelineConceptCard().frame(maxWidth: .infinity, alignment: .topLeading)
                AportarListConceptCard().frame(maxWidth: .infinity, alignment: .topLeading)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("How Grove gets you there")
                .font(.system(size: Theme.FontSize.title2, weight: .bold))
            Text("Your Freedom Number is the destination. Three things keep you on the path.")
                .font(.callout)
                .foregroundStyle(Color.tqSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Cards

private struct StrategyConceptCard: View {
    var body: some View {
        ConceptCard(
            number: "1",
            icon: "chart.pie.fill",
            tint: Color.tqAccentGreen,
            title: "Strategy",
            copy: Text("Your money is split across classes — Brazilian stocks, FIIs, US stocks, REITs, crypto, fixed income. You set the percentages on the next screen.")
        )
    }
}

private struct PipelineConceptCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ConceptCardHeader(
                number: "2",
                icon: "arrow.triangle.branch",
                tint: HoldingStatus.aportar.color,
                title: "Pipeline"
            )
            Text("Every asset has a status. Only **Invest** receives monthly buy recommendations — that's the status that turns the engine on.")
                .font(.callout)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ForEach(HoldingStatus.allCases) { status in
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Image(systemName: status.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(status.color)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(status.displayName)
                                .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                            Text(status.description)
                                .font(.system(size: Theme.FontSize.caption))
                                .foregroundStyle(Color.tqSecondaryText)
                        }
                    }
                }
            }
            .padding(.top, Theme.Spacing.xs)
        }
        .padding(Theme.Spacing.lg)
        .background(Color.tqCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }
}

private struct AportarListConceptCard: View {
    var body: some View {
        ConceptCard(
            number: "3",
            icon: "list.bullet.rectangle.portrait.fill",
            tint: Color.tqAccentGreen,
            title: "Aportar list",
            copy: Text("Every month, Grove ranks the underweight Invest assets and tells you exactly where to put your contribution.")
        )
    }
}

// MARK: - Building blocks

private struct ConceptCard: View {
    let number: String
    let icon: String
    let tint: Color
    let title: String
    let copy: Text

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ConceptCardHeader(number: number, icon: icon, tint: tint, title: title)
            copy
                .font(.callout)
                .foregroundStyle(.primary)
        }
        .padding(Theme.Spacing.lg)
        .background(Color.tqCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }
}

private struct ConceptCardHeader: View {
    let number: String
    let icon: String
    let tint: Color
    let title: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(verbatim: number)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(tint, in: Circle())
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: Theme.FontSize.body, weight: .semibold))
            Spacer(minLength: 0)
        }
    }
}

#Preview("Compact") {
    HowGroveWorksStepView()
        .environment(\.horizontalSizeClass, .compact)
        .preferredColorScheme(.dark)
}

#Preview("Regular") {
    HowGroveWorksStepView()
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 900, height: 600)
        .preferredColorScheme(.dark)
}
