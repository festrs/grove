import SwiftUI

struct TQProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    var accentColor: Color = .tqAccentGreen

    /// Clamp to `[0, 1]` and treat non-finite (NaN/∞) as zero. Without this,
    /// passing a NaN progress (e.g. `current / 0`) reaches `.trim` and emits
    /// SwiftUI's "Invalid frame dimension (negative or non-finite)" warning.
    private var safeProgress: Double {
        guard progress.isFinite else { return 0 }
        return max(0, min(progress, 1))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(accentColor.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: safeProgress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: safeProgress)
        }
        .frame(width: size, height: size)
    }
}
