import SwiftUI

#if os(iOS)

private struct KeyboardDoneBarModifier: ViewModifier {
    @State private var keyboardVisible = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if keyboardVisible {
                    keyboardBar
                        .transition(.move(edge: .bottom))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeOut(duration: 0.2)) { keyboardVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.2)) { keyboardVisible = false }
            }
    }

    // Mirrors the native UIKit input accessory bar: 44pt tall, translucent
    // material backdrop matching the keyboard, hairline top separator,
    // right-aligned Done in the system accent.
    private var keyboardBar: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .fontWeight(.semibold)
                .padding(.trailing, 16)
            }
            .frame(maxWidth: .infinity, minHeight: 44)

            Divider()
        }
        .background(.bar)
    }
}

extension View {
    /// Adds a "Done" bar that floats above the keyboard whenever any text field
    /// in this view's hierarchy is focused. Use on screens with `.decimalPad` or
    /// `.numberPad` keyboards, which have no built-in dismiss key.
    func keyboardDoneBar() -> some View {
        modifier(KeyboardDoneBarModifier())
    }
}

#else

extension View {
    func keyboardDoneBar() -> some View { self }
}

#endif
