import SwiftUI
import GroveDomain

// ============================================================
// MARK: - Shared: Weight row data & total footer
// ============================================================

struct WeightRowData {
    let assetClass: AssetClassType
    let holdingCount: Int
}

/// Reusable total footer for all weight input options
struct WeightTotalFooter: View {
    let total: Double

    var isValid: Bool { abs(total - 100) < 0.5 }

    var body: some View {
        HStack {
            Text("Total").fontWeight(.semibold)
            Spacer()
            Text(String(format: "%.0f%%", total))
                .fontWeight(.semibold)
                .foregroundStyle(isValid ? Color.tqAccentGreen : Color.tqNegative)
        }
        .padding(.top, Theme.Spacing.sm)
    }
}

/// Reusable row label (color dot + name + count)
struct WeightRowLabel: View {
    let data: WeightRowData

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Circle().fill(data.assetClass.color).frame(width: 10, height: 10)
            Text(data.assetClass.displayName).font(.subheadline)
            if data.holdingCount > 0 {
                Text("(\(data.holdingCount))").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}

/// Builds row data from holdings
private func buildRows(holdings: [Holding]) -> [WeightRowData] {
    AssetClassType.allCases.map { ct in
        WeightRowData(assetClass: ct, holdingCount: holdings.filter { $0.assetClass == ct }.count)
    }
}

// ============================================================
// MARK: - Option A: Stepper Only
// ============================================================

struct WeightInputOptionA: View {
    @Binding var weights: [AssetClassType: Double]
    let holdings: [Holding]

    var body: some View {
        let rows = buildRows(holdings: holdings)
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.assetClass) { index, row in
                HStack {
                    WeightRowLabel(data: row)
                    Spacer()
                    Stepper(
                        String(format: "%.0f%%", weights[row.assetClass] ?? 0),
                        value: Binding(
                            get: { weights[row.assetClass] ?? 0 },
                            set: { weights[row.assetClass] = $0 }
                        ),
                        in: 0...100, step: 1
                    )
                    .frame(width: 160)
                }
                .padding(.vertical, 6)
                if index < rows.count - 1 { Divider() }
            }
            WeightTotalFooter(total: weights.values.reduce(0, +))
        }
    }
}

// ============================================================
// MARK: - Option B: Tappable Number (tap to edit)
// ============================================================

struct WeightInputOptionB: View {
    @Binding var weights: [AssetClassType: Double]
    let holdings: [Holding]
    @State private var editingClass: AssetClassType?
    @State private var editText = ""
    @FocusState private var focused: Bool

    var body: some View {
        let rows = buildRows(holdings: holdings)
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.assetClass) { index, row in
                let ct = row.assetClass
                HStack {
                    WeightRowLabel(data: row)
                    Spacer()
                    if editingClass == ct {
                        HStack(spacing: 2) {
                            TextField("0", text: $editText)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                                .font(.system(.body, weight: .semibold))
                                .focused($focused)
                                .onSubmit { commitEdit(ct) }
                            Text("%").foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    } else {
                        Text(String(format: "%.0f%%", weights[ct] ?? 0))
                            .font(.system(.body, weight: .semibold))
                            .monospacedDigit()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            .onTapGesture {
                                editText = String(format: "%.0f", weights[ct] ?? 0)
                                editingClass = ct
                                focused = true
                            }
                    }
                }
                .padding(.vertical, 6)
                if index < rows.count - 1 { Divider() }
            }
            WeightTotalFooter(total: weights.values.reduce(0, +))
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused, let ct = editingClass { commitEdit(ct) }
        }
    }

    private func commitEdit(_ ct: AssetClassType) {
        if let val = Double(editText) {
            weights[ct] = min(max(val, 0), 100)
        }
        editingClass = nil
    }
}

// ============================================================
// MARK: - Option C: +/- Buttons with Progress Bar
// ============================================================

struct WeightInputOptionC: View {
    @Binding var weights: [AssetClassType: Double]
    let holdings: [Holding]

    var body: some View {
        let rows = buildRows(holdings: holdings)
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.assetClass) { index, row in
                let ct = row.assetClass
                VStack(spacing: 4) {
                    HStack {
                        WeightRowLabel(data: row)
                        Spacer()
                        Text(String(format: "%.0f%%", weights[ct] ?? 0))
                            .font(.system(.title3, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(ct.color)
                    }
                    HStack(spacing: Theme.Spacing.md) {
                        Button { weights[ct] = max((weights[ct] ?? 0) - 5, 0) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2).foregroundStyle(ct.color.opacity(0.6))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.gray.opacity(0.15))
                                Capsule().fill(ct.color)
                                    .frame(width: geo.size.width * CGFloat((weights[ct] ?? 0) / 100))
                            }
                        }
                        .frame(height: 8)
                        Button { weights[ct] = min((weights[ct] ?? 0) + 5, 100) } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2).foregroundStyle(ct.color.opacity(0.6))
                        }
                    }
                }
                .padding(.vertical, 8)
                if index < rows.count - 1 { Divider() }
            }
            WeightTotalFooter(total: weights.values.reduce(0, +))
        }
    }
}

// ============================================================
// MARK: - Option D: Inline Text Field (no slider)
// ============================================================

struct WeightInputOptionD: View {
    @Binding var weights: [AssetClassType: Double]
    let holdings: [Holding]

    var body: some View {
        let rows = buildRows(holdings: holdings)
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.assetClass) { index, row in
                let ct = row.assetClass
                HStack {
                    WeightRowLabel(data: row)
                    Spacer()
                    HStack(spacing: 2) {
                        TextField("0", value: Binding(
                            get: { weights[ct] ?? 0 },
                            set: { weights[ct] = $0 }
                        ), format: .number)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                        .frame(width: 50)
                        .font(.system(.body, weight: .semibold))
                        .monospacedDigit()
                        Text("%").foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.vertical, 6)
                if index < rows.count - 1 { Divider() }
            }
            WeightTotalFooter(total: weights.values.reduce(0, +))
        }
    }
}

// ============================================================
// MARK: - Option E: Slider + Text Field Combo
// ============================================================

struct WeightInputOptionE: View {
    @Binding var weights: [AssetClassType: Double]
    let holdings: [Holding]

    var body: some View {
        let rows = buildRows(holdings: holdings)
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.assetClass) { index, row in
                let ct = row.assetClass
                VStack(spacing: 4) {
                    HStack {
                        WeightRowLabel(data: row)
                        Spacer()
                        HStack(spacing: 2) {
                            TextField("0", value: Binding(
                                get: { weights[ct] ?? 0 },
                                set: { weights[ct] = $0 }
                            ), format: .number)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 40)
                            .font(.system(.subheadline, weight: .semibold))
                            .monospacedDigit()
                            Text("%").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                    Slider(
                        value: Binding(
                            get: { weights[ct] ?? 0 },
                            set: { weights[ct] = $0 }
                        ),
                        in: 0...100, step: 1
                    )
                    .tint(ct.color)
                }
                .padding(.vertical, 4)
                if index < rows.count - 1 { Divider() }
            }
            WeightTotalFooter(total: weights.values.reduce(0, +))
        }
    }
}

// ============================================================
// MARK: - Showcase Preview
// ============================================================

private struct WeightOptionsPreview: View {
    @State private var wA: [AssetClassType: Double] = [.acoesBR: 30, .fiis: 25, .usStocks: 20, .reits: 10, .crypto: 10, .rendaFixa: 5]
    @State private var wB: [AssetClassType: Double] = [.acoesBR: 30, .fiis: 25, .usStocks: 20, .reits: 10, .crypto: 10, .rendaFixa: 5]
    @State private var wC: [AssetClassType: Double] = [.acoesBR: 30, .fiis: 25, .usStocks: 20, .reits: 10, .crypto: 10, .rendaFixa: 5]
    @State private var wD: [AssetClassType: Double] = [.acoesBR: 30, .fiis: 25, .usStocks: 20, .reits: 10, .crypto: 10, .rendaFixa: 5]
    @State private var wE: [AssetClassType: Double] = [.acoesBR: 30, .fiis: 25, .usStocks: 20, .reits: 10, .crypto: 10, .rendaFixa: 5]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                section("A: Stepper Only") { WeightInputOptionA(weights: $wA, holdings: []) }
                section("B: Tappable Number") { WeightInputOptionB(weights: $wB, holdings: []) }
                section("C: +/- Buttons with Bar") { WeightInputOptionC(weights: $wC, holdings: []) }
                section("D: Inline Text Field") { WeightInputOptionD(weights: $wD, holdings: []) }
                section("E: Slider + Text Field") { WeightInputOptionE(weights: $wE, holdings: []) }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color.tqBackground)
        .preferredColorScheme(.dark)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, Theme.Spacing.md)
            TQCard { content() }
        }
    }
}

#Preview("All Weight Options") {
    WeightOptionsPreview()
}
