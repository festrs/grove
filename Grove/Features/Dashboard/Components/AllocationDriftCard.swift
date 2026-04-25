import SwiftUI

struct AllocationDriftCard: View {
    let allocations: [AssetClassAllocation]

    var body: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ALOCACAO VS ALVO")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)
                        Text("Drift por classe")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    Spacer()
                }

                HStack(spacing: Theme.Spacing.lg) {
                    AllocationBar(allocations: allocations)
                }

                VStack(spacing: 10) {
                    ForEach(allocations) { alloc in
                        driftRow(alloc)
                    }
                }
            }
        }
    }

    private func driftRow(_ alloc: AssetClassAllocation) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(alloc.assetClass.color)
                .frame(width: 10, height: 10)

            Text(alloc.assetClass.displayName)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Drift bar
            GeometryReader { geo in
                let maxPct: CGFloat = 35
                let curWidth = CGFloat(NSDecimalNumber(decimal: alloc.currentPercent).doubleValue) / maxPct * geo.size.width
                let tgtPos = CGFloat(NSDecimalNumber(decimal: alloc.targetPercent).doubleValue) / maxPct * geo.size.width

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.tqAccentGreen)
                        .frame(width: min(curWidth, geo.size.width), height: 4)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white)
                        .frame(width: 2, height: 14)
                        .offset(x: min(tgtPos, geo.size.width) - 1)
                }
            }
            .frame(width: 72, height: 14)

            let gap = NSDecimalNumber(decimal: alloc.drift).doubleValue
            Text(String(format: "%+.0f%%", gap))
                .font(.system(size: 13, weight: abs(gap) >= 5 ? .semibold : .regular))
                .foregroundStyle(abs(gap) >= 5 ? Color.tqWarning : .secondary)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }
}
