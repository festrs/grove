import SwiftUI

struct TQProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    var accentColor: Color = .tqAccentGreen

    var body: some View {
        ZStack {
            Circle()
                .stroke(accentColor.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: progress)
        }
        .frame(width: size, height: size)
    }
}
