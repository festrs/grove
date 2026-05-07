import SwiftUI

/// Slider-based 1–5 priority picker for `Holding.targetPercent`. Used in
/// every surface that lets the user set within-class priority so the
/// control is visually identical wherever it appears (HoldingDetailView,
/// AddAssetDetailSheet's onboarding mode, and the AddHoldingsStepView
/// row). Two display variants:
///
/// - `.full` — slider + numeric label + help caption. Use in detail forms.
/// - `.compact` — slider + numeric label only. Use in tight rows.
///
/// The slider uses `step: 1` over `1...5`, so the value snaps to whole
/// numbers and the binding stays a `Decimal` to match the underlying
/// model field. Tint is `.tqAccentGreen` to match the rest of the app's
/// primary controls.
struct TQPriorityPicker: View {
    @Binding var value: Decimal
    var variant: Variant = .full

    enum Variant {
        case full
        case compact
    }

    private static let helpCaption = String(
        localized: "Relative weight for rebalancing (1 = lowest, 5 = highest priority)."
    )

    private var intValue: Int {
        NSDecimalNumber(decimal: value).intValue
    }

    var body: some View {
        switch variant {
        case .full:
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                sliderRow
                Text(Self.helpCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .compact:
            sliderRow
        }
    }

    private var sliderRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Slider(
                value: Binding(
                    get: { NSDecimalNumber(decimal: value).doubleValue },
                    set: { value = Decimal($0) }
                ),
                in: 1...5,
                step: 1
            )
            .tint(.tqAccentGreen)
            Text(verbatim: "\(intValue)")
                .font(.system(.body, design: .rounded, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.tqAccentGreen)
                .frame(width: 18, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Priority"))
        .accessibilityValue(Text(verbatim: "\(intValue) of 5"))
    }
}

#Preview("Full") {
    @Previewable @State var value: Decimal = 3
    return TQPriorityPicker(value: $value, variant: .full)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Compact") {
    @Previewable @State var value: Decimal = 5
    return TQPriorityPicker(value: $value, variant: .compact)
        .frame(width: 180)
        .padding()
        .preferredColorScheme(.dark)
}
