import SwiftUI
import Charts
import GroveDomain
import GroveServices

/// 12 past + 3 projected months of dividend income. Past bars are paid
/// (solid), the most-recent past bucket and the future buckets render as
/// projected (lighter). A horizontal goal line at the user's monthly goal
/// — the same goal the dashboard gauge tracks — lets the user read each
/// bar against the same reference shown on the gauge.
struct MonthlyTrendChart: View {
    let points: [IncomeAggregator.MonthlyIncomePoint]
    /// Monthly Freedom Plan goal. The gauge uses the identical value, so
    /// each bar in this chart can be read against the same target.
    let goal: Money?

    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    var body: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Monthly trend")
                    .font(.subheadline.weight(.semibold))

                Chart {
                    ForEach(points) { point in
                        let paidValue = doubleValue(point.paid)
                        let projectedValue = doubleValue(point.projected)

                        if paidValue > 0 {
                            BarMark(
                                x: .value("Month", Self.monthFormatter.string(from: point.monthStart)),
                                y: .value("Paid", paidValue)
                            )
                            .foregroundStyle(Color.tqAccentGreen.gradient)
                            .cornerRadius(4)
                        }
                        if projectedValue > 0 {
                            BarMark(
                                x: .value("Month", Self.monthFormatter.string(from: point.monthStart)),
                                y: .value("Projected", projectedValue)
                            )
                            .foregroundStyle(Color.tqAccentGreen.opacity(0.35).gradient)
                            .cornerRadius(4)
                        }
                    }
                    if let goal, goal.amount > 0 {
                        let v = doubleValue(goal)
                        RuleMark(y: .value("Goal", v))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                            .foregroundStyle(.orange)
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Goal \(goal.formatted(in: displayCurrency, using: rates))")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                    }
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Decimal(v).formattedCompact())
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label).font(.caption2)
                            }
                        }
                    }
                }
            }
        }
    }

    private func doubleValue(_ money: Money) -> Double {
        let converted = money.converted(to: displayCurrency, using: rates)
        return NSDecimalNumber(decimal: converted.amount).doubleValue
    }
}
