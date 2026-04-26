import SwiftUI
import Charts

struct HistoryBarChart: View {
    let monthlyData: [(month: String, value: Money)]
    let goal: Money
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

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
                                Text("\(last.value.formatted(in: displayCurrency, using: rates))/month")
                                    .font(.system(size: 24, weight: .bold))
                                    .monospacedDigit()

                                if let first = monthlyData.first, first.value.amount > 0 {
                                    let firstAmount = first.value.converted(to: displayCurrency, using: rates).amount
                                    let lastAmount = last.value.converted(to: displayCurrency, using: rates).amount
                                    let growth = ((lastAmount - firstAmount) / firstAmount) * 100
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
                        let amount = entry.value.converted(to: displayCurrency, using: rates).amount
                        BarMark(
                            x: .value("Mes", entry.month),
                            y: .value("Valor", NSDecimalNumber(decimal: amount).doubleValue)
                        )
                        .foregroundStyle(index == monthlyData.count - 1 ? Color.tqAccentGreen : Color.white.opacity(0.1))
                        .cornerRadius(3)
                    }

                    let goalAmount = goal.converted(to: displayCurrency, using: rates).amount
                    RuleMark(y: .value("Meta", NSDecimalNumber(decimal: goalAmount).doubleValue))
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
