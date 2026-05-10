import SwiftUI
import GroveDomain

/// Dashboard entry point into the Income Trends screen. The teaser copy
/// avoids stating any number — that would either duplicate the gauge above
/// (same paid+projected window) or confuse with a different aggregation.
/// The screen behind it surfaces history, top payers, and concentration.
struct IncomeTrendsTile: View {
    var body: some View {
        TQCard {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Color.tqAccentGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Income trends")
                        .font(.subheadline.weight(.semibold))
                    Text("12-month history · top payers · concentration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
