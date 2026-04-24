import SwiftUI

struct TQErrorView: View {
    let message: String
    var retryAction: (() async -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let retryAction {
                Button("Tentar novamente") {
                    Task { await retryAction() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.tqAccentGreen)
            }
        }
        .padding(Theme.Spacing.xl)
    }
}
