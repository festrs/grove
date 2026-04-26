import SwiftUI

struct AboutSection: View {
    var body: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            LabeledContent("Developed by", value: "Felipe Pereira")

            Link(destination: URL(string: "https://brapi.dev")!) {
                LabeledContent("Market Data") {
                    Text("brapi.dev")
                        .foregroundStyle(Color.tqAccentGreen)
                }
            }
        }
    }
}
