import SwiftUI

struct TQLoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
