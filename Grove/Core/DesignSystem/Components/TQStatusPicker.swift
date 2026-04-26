import SwiftUI

/// Compact capsule-style status picker matching `TQAssetClassPicker` visual pattern.
struct TQStatusPicker: View {
    @Binding var selection: HoldingStatus

    var body: some View {
        Menu {
            Picker("Status", selection: $selection) {
                ForEach(HoldingStatus.allCases) { status in
                    Label(status.displayName, systemImage: status.icon).tag(status)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selection.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(selection.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(0.6)
            }
            .foregroundStyle(selection.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(selection.color.opacity(0.15), in: Capsule())
            .animation(.spring(duration: 0.25), value: selection)
        }
        .buttonStyle(.plain)
    }
}
