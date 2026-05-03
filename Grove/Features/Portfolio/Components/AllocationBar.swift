import SwiftUI
import GroveDomain
import GroveRepositories

struct AllocationBar: View {
    let allocations: [AssetClassAllocation]
    @Environment(\.horizontalSizeClass) private var sizeClass
    private let lineWidth: CGFloat = 22

    private var size: CGFloat {
        Theme.Layout.chartSize(for: sizeClass) * 0.8
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // Donut chart — current allocation only
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: lineWidth)

                ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                    let start = slices.prefix(index).reduce(0.0) { $0 + $1.fraction }
                    let gapFraction = 2.0 / 360.0

                    Circle()
                        .trim(
                            from: CGFloat(start + gapFraction / 2),
                            to: CGFloat(start + slice.fraction - gapFraction / 2)
                        )
                        .stroke(slice.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: size, height: size)

            // Legend
            VStack(alignment: .leading, spacing: 6) {
                ForEach(allocations) { alloc in
                    let current = String(format: "%.0f", NSDecimalNumber(decimal: alloc.currentPercent).doubleValue)
                    let target = String(format: "%.0f", NSDecimalNumber(decimal: alloc.targetPercent).doubleValue)

                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(alloc.assetClass.color)
                            .frame(width: 10, height: 10)

                        Text(alloc.assetClass.shortName)
                            .font(.system(size: 12))
                            .lineLimit(1)

                        Spacer()

                        Text("\(current)/\(target)%")
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var slices: [(color: Color, fraction: Double)] {
        let total = allocations.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.currentPercent).doubleValue }
        guard total > 0 else { return [] }
        return allocations.map {
            (color: $0.assetClass.color, fraction: NSDecimalNumber(decimal: $0.currentPercent).doubleValue / total)
        }
    }
}

#Preview {
    AllocationBar(allocations: [
        AssetClassAllocation(assetClass: .acoesBR, currentValue: Money(amount: 5000, currency: .brl), currentPercent: 23, targetPercent: 30, drift: -7),
        AssetClassAllocation(assetClass: .fiis, currentValue: Money(amount: 2000, currency: .brl), currentPercent: 9, targetPercent: 20, drift: -11),
        AssetClassAllocation(assetClass: .usStocks, currentValue: Money(amount: 7000, currency: .brl), currentPercent: 31, targetPercent: 25, drift: 6),
        AssetClassAllocation(assetClass: .reits, currentValue: Money(amount: 2000, currency: .brl), currentPercent: 9, targetPercent: 10, drift: -1),
        AssetClassAllocation(assetClass: .crypto, currentValue: Money(amount: 6000, currency: .brl), currentPercent: 28, targetPercent: 15, drift: 13),
    ])
    .padding()
    .background(Color.tqBackground)
    .preferredColorScheme(.dark)
}
