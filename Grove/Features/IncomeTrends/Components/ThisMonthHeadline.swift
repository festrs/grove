import SwiftUI
import GroveDomain
import GroveServices

/// Headline that mirrors the dashboard gauge so the user sees the same
/// paid + projected number on both surfaces. Goal % and YoY trend sit
/// underneath as secondary context — the big number is the same one the
/// gauge displays.
struct ThisMonthHeadline: View {
    let summary: IncomeWindowSummary
    let goal: Money?
    let yoy: IncomeAggregator.YoYGrowth?

    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    var body: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(summary.total.formatted(in: displayCurrency, using: rates))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.tqAccentGreen)
                    }
                    Spacer()
                    if let yoyBadge {
                        Text(yoyBadge.text)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(yoyBadge.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(yoyBadge.color.opacity(0.12), in: Capsule())
                    }
                }

                HStack(spacing: Theme.Spacing.md) {
                    paidProjectedSplit
                    Spacer()
                    if let goalPercent {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("of goal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(goalPercent)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
    }

    private var paidProjectedSplit: some View {
        HStack(spacing: Theme.Spacing.sm) {
            label(title: "Paid", money: summary.paid, color: Color.tqAccentGreen)
            if summary.projected.amount > 0 {
                label(title: "Projected", money: summary.projected, color: Color.tqAccentGreen.opacity(0.5))
            }
        }
    }

    private func label(title: String, money: Money, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(money.formatted(in: displayCurrency, using: rates))
                    .font(.caption.weight(.medium))
            }
        }
    }

    private var goalPercent: String? {
        guard let goal, goal.amount > 0 else { return nil }
        let total = summary.total.converted(to: displayCurrency, using: rates).amount
        let goalAmount = goal.converted(to: displayCurrency, using: rates).amount
        let pct = (total / goalAmount) * 100
        return pct.formattedPercent()
    }

    private var yoyBadge: (text: String, color: Color)? {
        guard let pct = yoy?.percent else { return nil }
        if pct > 0 { return (pct.formattedSignedPercent(), .tqPositive) }
        if pct < 0 { return (pct.formattedSignedPercent(), .tqNegative) }
        return (pct.formattedSignedPercent(), .secondary)
    }
}

private extension Decimal {
    func formattedPercent() -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        let n = NSDecimalNumber(decimal: self)
        return "\(nf.string(from: n) ?? "0")%"
    }

    func formattedSignedPercent() -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 1
        let sign = self > 0 ? "+" : ""
        let n = NSDecimalNumber(decimal: self)
        return "\(sign)\(nf.string(from: n) ?? "0")% YoY"
    }
}
