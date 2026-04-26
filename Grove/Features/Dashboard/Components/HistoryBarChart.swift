import SwiftUI
import Charts

struct HistoryBarChart: View {
    let monthlyData: [(month: String, value: Decimal)]
    let goal: Decimal

    var body: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HISTORY · 12 MONTHS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)

                        if let last = monthlyData.last {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(last.value.formattedBRL())/month")
                                    .font(.system(size: 24, weight: .bold))
                                    .monospacedDigit()

                                if let first = monthlyData.first, first.value > 0 {
                                    let growth = ((last.value - first.value) / first.value) * 100
                                    let growthStr = String(format: "+%.0f%%", NSDecimalNumber(decimal: growth).doubleValue)
                                    Text(growthStr)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.tqAccentGreen)
                                }
                            }
                        }
                    }

                    Spacer()
                }

                Chart {
                    ForEach(Array(monthlyData.enumerated()), id: \.offset) { index, entry in
                        BarMark(
                            x: .value("Mes", entry.month),
                            y: .value("Valor", NSDecimalNumber(decimal: entry.value).doubleValue)
                        )
                        .foregroundStyle(index == monthlyData.count - 1 ? Color.tqAccentGreen : Color.white.opacity(0.1))
                        .cornerRadius(3)
                    }

                    RuleMark(y: .value("Meta", NSDecimalNumber(decimal: goal).doubleValue))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .annotation(position: .trailing, alignment: .trailing) {
                            Text("goal")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 120)
            }
        }
    }
}
