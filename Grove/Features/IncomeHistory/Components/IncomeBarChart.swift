import SwiftUI
import Charts

struct IncomeBarChart: View {
    let summaries: [MonthlyDividendSummary]
    let showNet: Bool
    var goalLine: Decimal?

    var body: some View {
        Chart {
            ForEach(summaries) { summary in
                let value = showNet
                    ? NSDecimalNumber(decimal: summary.net).doubleValue
                    : NSDecimalNumber(decimal: summary.gross).doubleValue

                BarMark(
                    x: .value("Month", summary.monthLabel),
                    y: .value("Income", value)
                )
                .foregroundStyle(Color.tqAccentGreen.gradient)
                .cornerRadius(4)
            }

            if let goal = goalLine {
                RuleMark(y: .value("Goal", NSDecimalNumber(decimal: goal).doubleValue))
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
