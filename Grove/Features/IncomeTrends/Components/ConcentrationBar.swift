import SwiftUI
import GroveDomain
import GroveServices

/// "Top 3 holdings = 64% of your dividend income" — a concentration risk
/// signal that exists nowhere else in the app. Renders as a stacked bar so
/// the user can see both the headline number and the per-holding split.
struct ConcentrationBar: View {
    let concentration: IncomeAggregator.Concentration
    /// Mirrors the topN passed to `IncomeAggregator.concentration`. Used in
    /// the headline copy ("Top \(topN) = X%").
    let topN: Int

    private static let palette: [Color] = [
        .tqAccentGreen,
        .blue,
        .orange,
        .purple,
        .pink,
        .cyan,
        .gray,
    ]

    var body: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if concentration.segments.isEmpty {
                    Text("Income concentration")
                        .font(.subheadline.weight(.semibold))
                    Text("No paying holdings yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    headline
                    bar
                    legend
                }
            }
        }
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Top \(min(topN, concentration.segments.count)) holdings")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(verbatim: concentration.topShare.formattedPercent())
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.tqAccentGreen)
        }
    }

    private var bar: some View {
        GeometryReader { proxy in
            HStack(spacing: 1) {
                ForEach(Array(concentration.segments.enumerated()), id: \.element.id) { idx, segment in
                    color(for: idx, label: segment.label)
                        .frame(width: width(for: segment.share, in: proxy.size.width))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 12)
    }

    private var legend: some View {
        FlowLayoutCompat(spacing: 6) {
            ForEach(Array(concentration.segments.enumerated()), id: \.element.id) { idx, segment in
                HStack(spacing: 4) {
                    Circle()
                        .fill(color(for: idx, label: segment.label))
                        .frame(width: 6, height: 6)
                    Text(verbatim: "\(segment.label) \(segment.share.formattedPercent())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func color(for index: Int, label: String) -> Color {
        if label == "Rest" { return .gray.opacity(0.4) }
        return Self.palette[index % Self.palette.count]
    }

    private func width(for share: Decimal, in total: CGFloat) -> CGFloat {
        let pct = NSDecimalNumber(decimal: share).doubleValue
        return total * CGFloat(pct / 100)
    }
}

/// Minimal flow layout — wrapping line of legend chips. Keeps the
/// dependency surface tiny (no `Layout` protocol gymnastics).
private struct FlowLayoutCompat<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        // Falls back to a simple HStack-of-rows; SwiftUI's `Layout` protocol
        // would be cleaner but isn't worth the surface area for ≤7 chips.
        HStack(alignment: .center, spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension Decimal {
    func formattedPercent() -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 1
        nf.minimumFractionDigits = 0
        let n = NSDecimalNumber(decimal: self)
        return "\(nf.string(from: n) ?? "0")%"
    }
}
