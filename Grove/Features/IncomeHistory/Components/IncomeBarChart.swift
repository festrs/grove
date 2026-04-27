import SwiftUI
import Charts
import GroveDomain

struct IncomeBarChart: View {
    let summaries: [MonthlyDividendSummary]
    let showNet: Bool
    var goalLine: Money?

    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    var body: some View {
        Chart {
            ForEach(summaries) { summary in
                let money = showNet ? summary.netMoney : summary.grossMoney
                let value = NSDecimalNumber(decimal: money.converted(to: displayCurrency, using: rates).amount).doubleValue

                BarMark(
                    x: .value("Month", summary.monthLabel),
                    y: .value("Income", value)
                )
                .foregroundStyle(Color.tqAccentGreen.gradient)
                .cornerRadius(4)
            }

            if let goal = goalLine {
                let value = NSDecimalNumber(decimal: goal.converted(to: displayCurrency, using: rates).amount).doubleValue
                RuleMark(y: .value("Goal", value))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(.orange)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
            }
        }
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
                        Text(label)
                            .font(.caption2)
                    }
                }
            }
        }
    }
}
