import SwiftUI
import Charts

struct AllocationComparisonChart: View {
    let suggestions: [RebalancingSuggestion]

    var body: some View {
        Chart {
            ForEach(suggestions) { s in
                BarMark(
                    x: .value("Ticker", s.ticker),
                    y: .value("Atual", NSDecimalNumber(decimal: s.currentPercent).doubleValue)
                )
                .foregroundStyle(.gray.opacity(0.4))
                .position(by: .value("Type", "Atual"))

                BarMark(
                    x: .value("Ticker", s.ticker),
                    y: .value("Novo", NSDecimalNumber(decimal: s.newPercent).doubleValue)
                )
                .foregroundStyle(Color.tqAccentGreen)
                .position(by: .value("Type", "Novo"))

                BarMark(
                    x: .value("Ticker", s.ticker),
                    y: .value("Alvo", NSDecimalNumber(decimal: s.targetPercent).doubleValue)
                )
                .foregroundStyle(.orange.opacity(0.5))
                .position(by: .value("Type", "Alvo"))
            }
        }
        .chartLegend(position: .bottom)
        .frame(height: 200)
    }
}
