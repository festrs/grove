import SwiftUI

struct DividendDayCell: View {
    let day: Int
    let hasDividend: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)

            Circle()
                .fill(hasDividend ? Color.tqAccentGreen : .clear)
                .frame(width: 6, height: 6)
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.tqAccentGreen : Color.clear)
        )
    }
}
