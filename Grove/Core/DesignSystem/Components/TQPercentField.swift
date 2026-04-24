import SwiftUI

struct TQPercentField: View {
    let title: String
    @Binding var value: Decimal

    @State private var textValue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("0", text: $textValue)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .onChange(of: textValue) { _, newValue in
                        let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                        if let decimal = Decimal(string: cleaned) {
                            value = min(max(decimal, 0), 100)
                        }
                    }
                Text("%")
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.sm)
            .background(Color.tqCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
        }
        .onAppear {
            if value > 0 {
                textValue = "\(value)"
            }
        }
    }
}
