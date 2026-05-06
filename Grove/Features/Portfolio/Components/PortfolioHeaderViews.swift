import SwiftUI
import SwiftData
import GroveDomain

/// Direct rename + import buttons rendered inline in the portfolio top bar.
/// The portfolio screen hides the native nav bar, so these are custom
/// buttons sized to a 44pt tap target rather than the default tiny
/// `Button(label:)` rendering.
struct PortfolioActionButtons: View {
    let onEdit: () -> Void
    let onAdd: () -> Void
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            iconButton("pencil", help: "Rename Portfolio", action: onEdit)
            iconButton("plus", help: "Add Ticker", action: onAdd)
            iconButton("square.and.arrow.down", help: "Import", action: onImport)
        }
    }

    private func iconButton(
        _ systemImage: String,
        help: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.tqAccentGreen)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Big total + monthly income line shown above the allocation ring.
struct PortfolioTotalHeader: View {
    let totalValue: Money
    let monthlyIncomeNet: Money?
    var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(height: 40)
            } else {
                Text(verbatim: totalValue.formatted())
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                if let income = monthlyIncomeNet {
                    Text("Monthly income: \(income.formatted())")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
    }
}

/// Asset-class filter strip. Renders horizontal scroll on compact and a
/// flow layout (wraps) on wide.
struct AssetClassTabsRow: View {
    let holdings: [Holding]
    let selected: AssetClassType?
    let isWide: Bool
    let onSelect: (AssetClassType?) -> Void

    var body: some View {
        Group {
            if isWide {
                FlowLayout(spacing: Theme.Spacing.sm) {
                    buttons
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        buttons
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        AssetClassTab(title: "All", isSelected: selected == nil, color: .tqAccentGreen) {
            onSelect(nil)
        }
        ForEach(AssetClassType.allCases) { classType in
            let hasAny = holdings.contains { $0.assetClass == classType }
            if hasAny {
                AssetClassTab(
                    title: classType.displayName,
                    isSelected: selected == classType,
                    color: classType.color
                ) {
                    onSelect(classType)
                }
            }
        }
    }
}
