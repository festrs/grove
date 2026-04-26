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
        .onAppear { syncTextFromValue() }
        // Re-render when an external change (e.g. display currency switch) updates
        // the bound value or its currency. Skip while editing so we don't fight
        // the user's keystrokes.
        .onChange(of: value) { _, _ in
            if !isFocused { syncTextFromValue() }
        }
        .onChange(of: currency) { _, _ in
            if !isFocused { syncTextFromValue() }
        }
    }

    private func syncTextFromValue() {
        guard value > 0 else {
            textValue = ""
            return
        }
        textValue = Formatters.decimal(currency).string(from: value as NSDecimalNumber) ?? ""
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
