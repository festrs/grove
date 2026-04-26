import SwiftUI

/// Compact capsule-style asset class picker used across the app.
/// Shows icon + short name in a colored capsule with a dropdown chevron.
struct TQAssetClassPicker: View {
    @Binding var selection: AssetClassType

    var body: some View {
        Menu {
            Picker("Classe", selection: $selection) {
                ForEach(AssetClassType.allCases) { cls in
                    Label(cls.displayName, systemImage: cls.icon).tag(cls)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selection.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(selection.shortName)
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
