import SwiftUI
import GroveDomain

/// Liquid-Glass floating action bar shown via `safeAreaInset(edge: .bottom)`
/// while a holdings list is in multi-select edit mode. Mirrors the bottom
/// action pattern in Photos / Mail / Reminders: a single row of icon+label
/// buttons on a translucent glass capsule that floats above the tab bar.
///
/// Pure presentation — selection state, count, and the bulk mutations are
/// owned by the host view. The bar takes closures so it can be reused on any
/// future screen that needs the same edit-mode affordance.
struct BulkEditBar: View {
    let selectionCount: Int
    let allSelected: Bool
    let currentAssetClass: AssetClassType?
    let onToggleSelectAll: () -> Void
    let onApplyStatus: (HoldingStatus) -> Void
    let onApplyAssetClass: (AssetClassType) -> Void
    let onDelete: () -> Void

    private var hasSelection: Bool { selectionCount > 0 }

    var body: some View {
        HStack(spacing: 0) {
            selectAllAction
            statusAction
            classAction
            deleteAction
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .glassActionBar()
    }

    // MARK: - Actions

    private var selectAllAction: some View {
        Button(action: onToggleSelectAll) {
            actionLabel(
                systemImage: allSelected ? "checklist.checked" : "checklist",
                title: allSelected ? "Deselect All" : "Select All",
                tint: .accentColor,
                enabled: true
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var statusAction: some View {
        Menu {
            ForEach(HoldingStatus.allCases) { status in
                Button {
                    onApplyStatus(status)
                } label: {
                    Label(status.displayName, systemImage: status.icon)
                }
            }
        } label: {
            actionLabel(systemImage: "tag", title: "Status", tint: .accentColor, enabled: hasSelection)
        }
        .disabled(!hasSelection)
        .frame(maxWidth: .infinity)
    }

    private var classAction: some View {
        Menu {
            ForEach(AssetClassType.allCases) { cls in
                Button {
                    onApplyAssetClass(cls)
                } label: {
                    Label(cls.displayName, systemImage: cls.icon)
                }
                .disabled(cls == currentAssetClass)
            }
        } label: {
            actionLabel(systemImage: "square.grid.2x2", title: "Class", tint: .accentColor, enabled: hasSelection)
        }
        .disabled(!hasSelection)
        .frame(maxWidth: .infinity)
    }

    private var deleteAction: some View {
        Button(role: .destructive, action: onDelete) {
            actionLabel(systemImage: "trash", title: "Delete", tint: .red, enabled: hasSelection)
        }
        .buttonStyle(.plain)
        .disabled(!hasSelection)
        .frame(maxWidth: .infinity)
    }

    private func actionLabel(
        systemImage: String,
        title: LocalizedStringKey,
        tint: Color,
        enabled: Bool
    ) -> some View {
        VStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .regular))
            Text(title)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(enabled ? AnyShapeStyle(tint) : AnyShapeStyle(Color.secondary.opacity(0.55)))
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
    }
}


#Preview("Empty selection") {
    VStack {
        Spacer()
        BulkEditBar(
            selectionCount: 0,
            allSelected: false,
            currentAssetClass: .acoesBR,
            onToggleSelectAll: {},
            onApplyStatus: { _ in },
            onApplyAssetClass: { _ in },
            onDelete: {}
        )
    }
}

#Preview("Some selected") {
    VStack {
        Spacer()
        BulkEditBar(
            selectionCount: 3,
            allSelected: false,
            currentAssetClass: .acoesBR,
            onToggleSelectAll: {},
            onApplyStatus: { _ in },
            onApplyAssetClass: { _ in },
            onDelete: {}
        )
    }
}
