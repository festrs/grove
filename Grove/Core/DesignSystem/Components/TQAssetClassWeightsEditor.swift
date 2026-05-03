import SwiftUI
import GroveDomain

/// Stateless editor for per-asset-class target weights. Iterates
/// `AssetClassType.allCases` so users always see the full universe of classes,
/// not just the ones they currently hold. Backed by a `Binding<[AssetClassType: Double]>`
/// so callers (Settings, Onboarding) can plug in their own ViewModel storage.
///
/// The component yields a flat `Group` of rows (and an optional Total row), so it
/// renders cleanly both as Form Section rows and inside a VStack/ScrollView.
struct TQAssetClassWeightsEditor: View {
    @Binding var weights: [AssetClassType: Double]
    var caption: ((AssetClassType) -> String?)? = nil
    var showsTotal: Bool = true

    var total: Double {
        AssetClassType.allCases.reduce(0) { $0 + (weights[$1] ?? 0) }
    }

    var isValid: Bool {
        abs(total - 100) < 0.5
    }

    var body: some View {
        Group {
            ForEach(AssetClassType.allCases) { cls in
                row(for: cls)
            }
            if showsTotal {
                totalRow
            }
        }
    }

    private func row(for cls: AssetClassType) -> some View {
        let value = weights[cls] ?? 0
        let binding = Binding<Double>(
            get: { weights[cls] ?? 0 },
            set: { weights[cls] = $0 }
        )
        return HStack(spacing: Theme.Spacing.sm) {
            Circle()
                .fill(cls.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(cls.displayName)
                    .font(.subheadline)
                if let caption = caption?(cls) {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(Int(value))%")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(value > 0 ? .primary : .secondary)
                .frame(width: 44, alignment: .trailing)

            Stepper("", value: binding, in: 0...100, step: 1)
                .labelsHidden()
        }
    }

    private var totalRow: some View {
        HStack {
            Text("Total")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(Int(total))%")
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(isValid ? Color.tqAccentGreen : Color.tqNegative)
        }
    }
}

#Preview("Form (Settings)") {
    @Previewable @State var weights: [AssetClassType: Double] = [
        .acoesBR: 30, .fiis: 25, .usStocks: 15, .reits: 10, .crypto: 5, .rendaFixa: 15
    ]
    return Form {
        Section {
            TQAssetClassWeightsEditor(weights: $weights)
        } header: {
            Text("Allocation by Class")
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Card (Onboarding)") {
    @Previewable @State var weights: [AssetClassType: Double] = [
        .acoesBR: 40, .fiis: 30, .usStocks: 10, .reits: 0, .crypto: 5, .rendaFixa: 15
    ]
    let captions: [AssetClassType: String] = [.acoesBR: "2 assets", .fiis: "1 asset"]
    return ScrollView {
        TQCard {
            VStack(spacing: Theme.Spacing.sm) {
                TQAssetClassWeightsEditor(
                    weights: $weights,
                    caption: { captions[$0] ?? "No assets yet" }
                )
            }
        }
        .padding()
    }
    .background(Color.tqBackground)
    .preferredColorScheme(.dark)
}
