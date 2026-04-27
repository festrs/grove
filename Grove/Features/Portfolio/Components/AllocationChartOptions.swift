import SwiftUI
import GroveDomain
import GroveRepositories

// MARK: - Shared helpers

private let previewData: [AssetClassAllocation] = [
    AssetClassAllocation(assetClass: .acoesBR, currentValue: Money(amount: 5000, currency: .brl), currentPercent: 23, targetPercent: 30, drift: -7),
    AssetClassAllocation(assetClass: .fiis, currentValue: Money(amount: 2000, currency: .brl), currentPercent: 9, targetPercent: 20, drift: -11),
    AssetClassAllocation(assetClass: .usStocks, currentValue: Money(amount: 7000, currency: .brl), currentPercent: 31, targetPercent: 25, drift: 6),
    AssetClassAllocation(assetClass: .reits, currentValue: Money(amount: 2000, currency: .brl), currentPercent: 9, targetPercent: 10, drift: -1),
    AssetClassAllocation(assetClass: .crypto, currentValue: Money(amount: 6000, currency: .brl), currentPercent: 28, targetPercent: 15, drift: 13),
]

private struct DonutSlice {
    let color: Color
    let fraction: Double
}

private func buildSlices(_ allocations: [AssetClassAllocation], keyPath: KeyPath<AssetClassAllocation, Decimal>, opacity: Double = 1) -> [DonutSlice] {
    let total = allocations.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1[keyPath: keyPath]).doubleValue }
    guard total > 0 else { return [] }
    return allocations.map {
        DonutSlice(
            color: $0.assetClass.color.opacity(opacity),
            fraction: NSDecimalNumber(decimal: $0[keyPath: keyPath]).doubleValue / total
        )
    }
}

private struct DonutRing: View {
    let slices: [DonutSlice]
    let size: CGFloat
    let lineWidth: CGFloat
    var gapDegrees: Double = 0
    var lineCap: CGLineCap = .butt

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: lineWidth)

            ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                let start = startAngle(for: index)
                let gapFraction = gapDegrees / 360.0
                let trimStart = start + gapFraction / 2
                let trimEnd = start + slice.fraction - gapFraction / 2

                if trimEnd > trimStart {
                    Circle()
                        .trim(from: CGFloat(trimStart), to: CGFloat(trimEnd))
                        .stroke(slice.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: lineCap))
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func startAngle(for index: Int) -> Double {
        slices.prefix(index).reduce(0) { $0 + $1.fraction }
    }
}

// ============================================================
// MARK: - Option 1: Single Donut with Segment Gaps
// ============================================================

struct AllocationOption1: View {
    let allocations: [AssetClassAllocation]

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            DonutRing(
                slices: buildSlices(allocations, keyPath: \.currentPercent),
                size: 140,
                lineWidth: 26,
                gapDegrees: 2,
                lineCap: .butt
            )
            .frame(width: 140, height: 140)

            legend
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(allocations) { alloc in
                HStack(spacing: Theme.Spacing.sm) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(alloc.assetClass.color)
                        .frame(width: 12, height: 12)
                    Text(alloc.assetClass.displayName)
                        .font(.system(size: 14))
                    Spacer()
                    Text(alloc.currentPercent.formattedPercent(decimals: 0))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

// ============================================================
// MARK: - Option 2: Single Donut + Ghost Tick Marks for Targets
// ============================================================

struct AllocationOption2: View {
    let allocations: [AssetClassAllocation]
    private let size: CGFloat = 140
    private let lineWidth: CGFloat = 26

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            ZStack {
                DonutRing(
                    slices: buildSlices(allocations, keyPath: \.currentPercent),
                    size: size,
                    lineWidth: lineWidth,
                    gapDegrees: 2
                )

                // Target tick marks
                ForEach(Array(targetAngles.enumerated()), id: \.offset) { _, angle in
                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 2, height: lineWidth + 6)
                        .offset(y: -(size / 2))
                        .rotationEffect(.degrees(angle))
                }
            }
            .frame(width: size, height: size)

            legend
        }
    }

    private var targetAngles: [Double] {
        let total = allocations.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.targetPercent).doubleValue }
        guard total > 0 else { return [] }
        var angles: [Double] = []
        var cumulative = 0.0
        for alloc in allocations.dropLast() {
            cumulative += NSDecimalNumber(decimal: alloc.targetPercent).doubleValue / total
            angles.append(cumulative * 360)
        }
        return angles
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(allocations) { alloc in
                HStack(spacing: Theme.Spacing.sm) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(alloc.assetClass.color)
                        .frame(width: 12, height: 12)
                    Text(alloc.assetClass.displayName)
                        .font(.system(size: 14))
                    Spacer()
                    Text(alloc.currentPercent.formattedPercent(decimals: 0))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

// ============================================================
// MARK: - Option 3: Stacked Arc Bars (per class)
// ============================================================

struct AllocationOption3: View {
    let allocations: [AssetClassAllocation]

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(allocations) { alloc in
                let current = NSDecimalNumber(decimal: alloc.currentPercent).doubleValue / 100
                let target = NSDecimalNumber(decimal: alloc.targetPercent).doubleValue / 100

                HStack(spacing: Theme.Spacing.sm) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(alloc.assetClass.color)
                        .frame(width: 12, height: 12)

                    Text(alloc.assetClass.displayName)
                        .font(.system(size: 13))
                        .frame(width: 75, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Target (background)
                            Capsule()
                                .fill(alloc.assetClass.color.opacity(0.2))
                                .frame(width: max(geo.size.width * CGFloat(target), 4))

                            // Current (foreground)
                            Capsule()
                                .fill(alloc.assetClass.color)
                                .frame(width: max(geo.size.width * CGFloat(current), 4))
                        }
                    }
                    .frame(height: 10)

                    Text(alloc.currentPercent.formattedPercent(decimals: 0))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 35, alignment: .trailing)
                }
            }
        }
    }
}

// ============================================================
// MARK: - Option 4: Donut with Floating Dashed Target Ring
// ============================================================

struct AllocationOption4: View {
    let allocations: [AssetClassAllocation]
    private let size: CGFloat = 140
    private let mainWidth: CGFloat = 22
    private let targetWidth: CGFloat = 4

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            ZStack {
                // Main donut
                DonutRing(
                    slices: buildSlices(allocations, keyPath: \.currentPercent),
                    size: size,
                    lineWidth: mainWidth,
                    gapDegrees: 2
                )

                // Outer dashed target ring
                let targetSize = size + mainWidth + 8
                DonutRing(
                    slices: buildSlices(allocations, keyPath: \.targetPercent, opacity: 0.4),
                    size: targetSize,
                    lineWidth: targetWidth,
                    gapDegrees: 1
                )
            }
            .frame(width: size + mainWidth + 16, height: size + mainWidth + 16)

            legend
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(allocations) { alloc in
                HStack(spacing: Theme.Spacing.sm) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(alloc.assetClass.color)
                        .frame(width: 12, height: 12)
                    Text(alloc.assetClass.displayName)
                        .font(.system(size: 14))
                    Spacer()
                    Text(alloc.currentPercent.formattedPercent(decimals: 0))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

// ============================================================
// MARK: - Option 5: Half-Donut (Gauge Style)
// ============================================================

struct AllocationOption5: View {
    let allocations: [AssetClassAllocation]
    private let size: CGFloat = 180
    private let lineWidth: CGFloat = 28

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                // Background track
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(Color.gray.opacity(0.15), lineWidth: lineWidth)
                    .rotationEffect(.degrees(180))

                // Segments
                let slices = buildSlices(allocations, keyPath: \.currentPercent)
                ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                    let start = slices.prefix(index).reduce(0.0) { $0 + $1.fraction }
                    let trimStart = start * 0.5
                    let trimEnd = (start + slice.fraction) * 0.5

                    Circle()
                        .trim(from: CGFloat(trimStart), to: CGFloat(trimEnd))
                        .stroke(slice.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(180))
                }

                // Target markers
                let targetSlices = buildSlices(allocations, keyPath: \.targetPercent)
                ForEach(Array(targetMarkerAngles(targetSlices).enumerated()), id: \.offset) { _, angle in
                    Triangle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 6, height: 8)
                        .offset(y: -(size / 2) + lineWidth / 2 + 10)
                        .rotationEffect(.degrees(angle))
                }
            }
            .frame(width: size, height: size / 2 + lineWidth)
            .offset(y: size / 4)
            .clipped()
            .frame(height: size / 2 + lineWidth / 2)

            // Legend
            HStack(spacing: Theme.Spacing.md) {
                ForEach(allocations) { alloc in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(alloc.assetClass.color)
                            .frame(width: 8, height: 8)
                        Text("\(alloc.assetClass.displayName)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func targetMarkerAngles(_ slices: [DonutSlice]) -> [Double] {
        var angles: [Double] = []
        var cumulative = 0.0
        for slice in slices.dropLast() {
            cumulative += slice.fraction
            angles.append(180 + cumulative * 180)
        }
        return angles
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// ============================================================
// MARK: - Option 6: Donut with Inner Summary + Drift Legend
// ============================================================

struct AllocationOption6: View {
    let allocations: [AssetClassAllocation]
    let totalValue: Decimal
    private let size: CGFloat = 140
    private let lineWidth: CGFloat = 22

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            ZStack {
                DonutRing(
                    slices: buildSlices(allocations, keyPath: \.currentPercent),
                    size: size,
                    lineWidth: lineWidth,
                    gapDegrees: 2
                )

                // Inner summary
                VStack(spacing: 2) {
                    let maxDrift = allocations.map { abs(NSDecimalNumber(decimal: $0.drift).doubleValue) }.max() ?? 0
                    let totalDrift = allocations.reduce(0.0) { $0 + abs(NSDecimalNumber(decimal: $1.drift).doubleValue) }

                    if totalDrift < 5 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.tqPositive)
                        Text("Balanced")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(format: "%.1f%%", maxDrift))
                            .font(.system(size: 18, weight: .bold))
                            .monospacedDigit()
                        Text("max drift")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: size, height: size)

            // Legend with drift
            VStack(alignment: .leading, spacing: 6) {
                ForEach(allocations) { alloc in
                    let drift = NSDecimalNumber(decimal: alloc.drift).doubleValue

                    HStack(spacing: Theme.Spacing.sm) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(alloc.assetClass.color)
                            .frame(width: 12, height: 12)

                        Text(alloc.assetClass.displayName)
                            .font(.system(size: 13))

                        Spacer()

                        Text(alloc.currentPercent.formattedPercent(decimals: 0))
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()

                        // Drift indicator
                        HStack(spacing: 1) {
                            Image(systemName: drift >= 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                            Text(String(format: "%.0f", abs(drift)) + "%")
                                .font(.system(size: 11))
                                .monospacedDigit()
                        }
                        .foregroundStyle(drift > 2 ? Color.tqNegative : drift < -2 ? Color.tqWarning : Color.tqPositive)
                        .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }
}

// ============================================================
// MARK: - Option 7: Progress Toward Target (per class rings)
// ============================================================

struct AllocationOption7: View {
    let allocations: [AssetClassAllocation]

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Mini rings row
            HStack(spacing: Theme.Spacing.md) {
                ForEach(allocations) { alloc in
                    let current = NSDecimalNumber(decimal: alloc.currentPercent).doubleValue
                    let target = NSDecimalNumber(decimal: alloc.targetPercent).doubleValue
                    let progress = target > 0 ? min(current / target, 1.5) : 0
                    let isOver = current > target

                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(alloc.assetClass.color.opacity(0.2), lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                                .stroke(
                                    isOver ? Color.tqWarning : alloc.assetClass.color,
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))

                            Text(String(format: "%.0f%%", current))
                                .font(.system(size: 9, weight: .bold))
                                .monospacedDigit()
                        }
                        .frame(width: 44, height: 44)

                        Text(alloc.assetClass.displayName)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text("/ \(String(format: "%.0f%%", target))")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

// ============================================================
// MARK: - Option 8: Bars with Remaining (filled + empty to target)
// ============================================================

struct AllocationOption8: View {
    let allocations: [AssetClassAllocation]

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(allocations) { alloc in
                let current = NSDecimalNumber(decimal: alloc.currentPercent).doubleValue
                let target = NSDecimalNumber(decimal: alloc.targetPercent).doubleValue
                let maxVal = max(current, target)
                let isOver = current > target

                HStack(spacing: Theme.Spacing.sm) {
                    Text(alloc.assetClass.displayName)
                        .font(.system(size: 12))
                        .frame(width: 70, alignment: .leading)

                    GeometryReader { geo in
                        let scale = maxVal > 0 ? geo.size.width / CGFloat(maxVal) : 0

                        ZStack(alignment: .leading) {
                            // Target outline
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(alloc.assetClass.color.opacity(0.3), lineWidth: 1)
                                .frame(width: CGFloat(target) * scale)

                            // Current fill
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isOver ? alloc.assetClass.color.opacity(0.8) : alloc.assetClass.color)
                                .frame(width: CGFloat(current) * scale)

                            // Target line marker
                            if !isOver {
                                Rectangle()
                                    .fill(alloc.assetClass.color.opacity(0.5))
                                    .frame(width: 1.5)
                                    .offset(x: CGFloat(target) * scale)
                            }
                        }
                    }
                    .frame(height: 14)

                    // Status
                    let diff = current - target
                    HStack(spacing: 2) {
                        if abs(diff) < 1 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.tqPositive)
                        } else {
                            Text(String(format: "%+.0f%%", diff))
                                .font(.system(size: 11, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(diff > 0 ? Color.tqWarning : Color.tqAccentGreen)
                        }
                    }
                    .frame(width: 38, alignment: .trailing)
                }
            }
        }
    }
}

// ============================================================
// MARK: - Option 9: Thermometer Bars (vertical fill toward target)
// ============================================================

struct AllocationOption9: View {
    let allocations: [AssetClassAllocation]

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(allocations) { alloc in
                let current = NSDecimalNumber(decimal: alloc.currentPercent).doubleValue
                let target = NSDecimalNumber(decimal: alloc.targetPercent).doubleValue
                let fillRatio = target > 0 ? min(current / target, 1.3) : 0
                let isOver = current > target

                VStack(spacing: 6) {
                    // Percentage
                    Text(String(format: "%.0f%%", current))
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()

                    // Vertical bar
                    GeometryReader { geo in
                        ZStack(alignment: .bottom) {
                            // Track (target height)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(alloc.assetClass.color.opacity(0.15))

                            // Fill (current)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [alloc.assetClass.color.opacity(0.6), alloc.assetClass.color],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(height: geo.size.height * CGFloat(min(fillRatio, 1.0)))

                            // Overflow indicator
                            if isOver {
                                VStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(Color.tqWarning)
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }

                            // Target line
                            if !isOver {
                                VStack {
                                    Spacer()
                                        .frame(height: geo.size.height * CGFloat(1 - min(fillRatio, 1.0)))
                                    Rectangle()
                                        .fill(Color.white.opacity(0.4))
                                        .frame(height: 1)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .frame(width: 24, height: 70)

                    // Label
                    Text(alloc.assetClass.displayName)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: 50)

                    // Remaining
                    let remaining = target - current
                    if remaining > 0 {
                        Text(String(format: "+%.0f%%", remaining))
                            .font(.system(size: 9))
                            .foregroundStyle(Color.tqAccentGreen)
                    } else {
                        Text("OK")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.tqPositive)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// ============================================================
// MARK: - Option 10: Donut with Remaining Slice
// ============================================================

struct AllocationOption10: View {
    let allocations: [AssetClassAllocation]
    private let size: CGFloat = 140
    private let lineWidth: CGFloat = 24

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            ZStack {
                // Build slices: for underweight classes, show current (solid) + remaining (striped/faded)
                let slices = buildMixedSlices()

                DonutRing(
                    slices: slices,
                    size: size,
                    lineWidth: lineWidth,
                    gapDegrees: 1.5
                )

                // Center label
                VStack(spacing: 2) {
                    let underweight = allocations.filter { $0.drift < -1 }.count
                    if underweight == 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.tqPositive)
                        Text("Balanced")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(underweight)")
                            .font(.system(size: 22, weight: .bold))
                        Text("Below target")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: size, height: size)

            // Legend
            VStack(alignment: .leading, spacing: 6) {
                ForEach(allocations) { alloc in
                    let current = NSDecimalNumber(decimal: alloc.currentPercent).doubleValue
                    let target = NSDecimalNumber(decimal: alloc.targetPercent).doubleValue
                    let remaining = max(target - current, 0)

                    HStack(spacing: 6) {
                        // Solid + faded squares
                        HStack(spacing: 1) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(alloc.assetClass.color)
                                .frame(width: 6, height: 12)
                            if remaining > 0 {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(alloc.assetClass.color.opacity(0.25))
                                    .frame(width: 6, height: 12)
                            }
                        }

                        Text(alloc.assetClass.displayName)
                            .font(.system(size: 12))

                        Spacer()

                        if remaining > 0 {
                            Text("\(String(format: "%.0f", current)) / \(String(format: "%.0f%%", target))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        } else {
                            Text(String(format: "%.0f%%", current))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.tqPositive)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private func buildMixedSlices() -> [DonutSlice] {
        var slices: [DonutSlice] = []
        for alloc in allocations {
            let current = NSDecimalNumber(decimal: alloc.currentPercent).doubleValue
            let target = NSDecimalNumber(decimal: alloc.targetPercent).doubleValue
            let remaining = max(target - current, 0)

            // Current portion (solid)
            slices.append(DonutSlice(color: alloc.assetClass.color, fraction: current))
            // Remaining portion (faded)
            if remaining > 0 {
                slices.append(DonutSlice(color: alloc.assetClass.color.opacity(0.2), fraction: remaining))
            }
        }
        let total = slices.reduce(0) { $0 + $1.fraction }
        guard total > 0 else { return [] }
        return slices.map { DonutSlice(color: $0.color, fraction: $0.fraction / total) }
    }
}

// ============================================================
// MARK: - Option 11: Progress List (linear progress bars with labels)
// ============================================================

struct AllocationOption11: View {
    let allocations: [AssetClassAllocation]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(allocations) { alloc in
                let current = NSDecimalNumber(decimal: alloc.currentPercent).doubleValue
                let target = NSDecimalNumber(decimal: alloc.targetPercent).doubleValue
                let progress = target > 0 ? current / target : 0
                let isOver = current > target

                VStack(spacing: 4) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(alloc.assetClass.color)
                                .frame(width: 8, height: 8)
                            Text(alloc.assetClass.displayName)
                                .font(.system(size: 13, weight: .medium))
                        }

                        Spacer()

                        Text(String(format: "%.0f%%", current))
                            .font(.system(size: 13, weight: .bold))
                            .monospacedDigit()

                        Text("of \(String(format: "%.0f%%", target))")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.15))

                            Capsule()
                                .fill(
                                    isOver
                                    ? AnyShapeStyle(Color.tqWarning)
                                    : AnyShapeStyle(
                                        LinearGradient(
                                            colors: [alloc.assetClass.color.opacity(0.7), alloc.assetClass.color],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(min(progress, 1.0)))
                        }
                    }
                    .frame(height: 6)

                    // Remaining text
                    HStack {
                        Spacer()
                        if isOver {
                            Text("Excess \(String(format: "%.0f%%", current - target))")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.tqWarning)
                        } else if target - current < 1 {
                            Text("On target")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.tqPositive)
                        } else {
                            Text("Missing \(String(format: "%.0f%%", target - current))")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.tqAccentGreen)
                        }
                    }
                }
            }
        }
    }
}

// ============================================================
// MARK: - Option 12: Compact Rows with Inline Progress
// ============================================================

struct AllocationOption12: View {
    let allocations: [AssetClassAllocation]

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Header
            HStack {
                Text("Class")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 70, alignment: .leading)
                Text("Progress")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Current")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 35)
                Text("Target")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 35)
            }

            ForEach(allocations) { alloc in
                let current = NSDecimalNumber(decimal: alloc.currentPercent).doubleValue
                let target = NSDecimalNumber(decimal: alloc.targetPercent).doubleValue
                let progress = target > 0 ? current / target : 0
                let isOver = current > target

                HStack(spacing: Theme.Spacing.sm) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(alloc.assetClass.color)
                            .frame(width: 3, height: 20)
                        Text(alloc.assetClass.displayName)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .frame(width: 70, alignment: .leading)

                    // Inline bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(alloc.assetClass.color.opacity(0.12))

                            Capsule()
                                .fill(isOver ? Color.tqWarning : alloc.assetClass.color)
                                .frame(width: geo.size.width * CGFloat(min(progress, 1.0)))
                        }
                    }
                    .frame(height: 8)

                    Text(String(format: "%.0f%%", current))
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(isOver ? Color.tqWarning : .primary)
                        .frame(width: 35, alignment: .trailing)

                    Text(String(format: "%.0f%%", target))
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .frame(width: 35, alignment: .trailing)
                }
            }
        }
    }
}

// ============================================================
// MARK: - Showcase Preview
// ============================================================

#Preview("All Options") {
    ScrollView {
        VStack(spacing: 0) {
            optionSection("1: Single Donut + Gaps") {
                AllocationOption1(allocations: previewData)
            }
            optionSection("2: Donut + Target Ticks") {
                AllocationOption2(allocations: previewData)
            }
            optionSection("3: Stacked Arc Bars") {
                AllocationOption3(allocations: previewData)
            }
            optionSection("4: Donut + Target Ring") {
                AllocationOption4(allocations: previewData)
            }
            optionSection("5: Half-Donut Gauge") {
                AllocationOption5(allocations: previewData)
            }
            optionSection("6: Donut + Drift Legend") {
                AllocationOption6(allocations: previewData, totalValue: 22000)
            }
            optionSection("7: Per-Class Progress Rings") {
                AllocationOption7(allocations: previewData)
            }
            optionSection("8: Bars with Remaining") {
                AllocationOption8(allocations: previewData)
            }
            optionSection("9: Thermometer Bars") {
                AllocationOption9(allocations: previewData)
            }
            optionSection("10: Donut with Remaining Slices") {
                AllocationOption10(allocations: previewData)
            }
            optionSection("11: Progress List") {
                AllocationOption11(allocations: previewData)
            }
            optionSection("12: Compact Rows") {
                AllocationOption12(allocations: previewData)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.xl)
    }
    .background(Color.tqBackground)
    .preferredColorScheme(.dark)
}

@ViewBuilder
private func optionSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, Theme.Spacing.md)

        TQCard {
            content()
        }
    }
}
