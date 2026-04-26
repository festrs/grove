import SwiftUI

struct TQCurrencyField: View {
    let title: String
    let currency: Currency
    @Binding var value: Decimal

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text(currency.symbol)
                    .foregroundStyle(.secondary)
                TextField("0,00", text: $textValue)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .focused($isFocused)
                    .onChange(of: textValue) { _, newValue in
                        parseValue(newValue)
                    }
            }
            .padding(Theme.Spacing.sm)
            .background(Color.tqCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
        }
        .onAppear {
            if value > 0 {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.locale = currency.locale
                formatter.minimumFractionDigits = 2
                formatter.maximumFractionDigits = 2
                textValue = formatter.string(from: value as NSDecimalNumber) ?? ""
            }
        }
    }

    private func parseValue(_ text: String) {
        let cleaned = text
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        if let decimal = Decimal(string: cleaned) {
            value = decimal
        }
    }
}
