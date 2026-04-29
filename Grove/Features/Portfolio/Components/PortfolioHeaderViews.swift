import SwiftUI
import SwiftData
import GroveDomain

/// Portfolio name + chevron menu used in the top bar of both Compact and
/// Wide portfolio variants.
struct PortfolioSelectorMenu: View {
    let portfolios: [Portfolio]
    let selected: Portfolio?
    let onSelect: (Portfolio) -> Void

    var body: some View {
        Menu {
            ForEach(portfolios, id: \.persistentModelID) { portfolio in
                Button {
                    onSelect(portfolio)
                } label: {
                    HStack {
                        Text(portfolio.name)
                        if portfolio.name == selected?.name {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selected?.name ?? "Portfolio")
                    .font(.headline).fontWeight(.bold)
                Image(systemName: "chevron.down")
                    .font(.caption).fontWeight(.semibold)
            }
            .foregroundStyle(.primary)
        }
    }
}

/// Edit / New / Import portfolio overflow menu.
struct PortfolioOverflowMenu: View {
    let onEdit: () -> Void
    let onNew: () -> Void
    let onImport: () -> Void

    var body: some View {
        Menu {
            Button {
                onEdit()
            } label: {
                Label("Edit Portfolio", systemImage: "pencil")
            }
            Button {
                onNew()
            } label: {
                Label("New Portfolio", systemImage: "folder.badge.plus")
            }
            Divider()
            Button {
                onImport()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

/// Big total + monthly income line shown above the allocation ring.
struct PortfolioTotalHeader: View {
    let totalValue: Money
    let monthlyIncomeNet: Money?

    var body: some View {
        VStack(spacing: 4) {
            Text(totalValue.formatted())
                .font(.system(size: 32, weight: .bold, design: .rounded))
            if let income = monthlyIncomeNet {
                Text("Monthly income: \(income.formatted())")
                    .font(.subheadline).foregroundStyle(.secondary)
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
            let count = holdings.filter { $0.assetClass == classType }.count
            if count > 0 {
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

/// Sheet for naming a brand-new portfolio.
struct NewPortfolioSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    let onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Portfolio Name") {
                    TextField("E.g.: Retirement, Children", text: $name)
                }
            }
            .navigationTitle("New Portfolio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { onCreate(name); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
