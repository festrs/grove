import SwiftUI

struct AboutSection: View {
    var body: some View {
        Section("Sobre") {
            LabeledContent("Versao", value: "1.0.0")
            LabeledContent("Desenvolvido por", value: "Felipe Pereira")

            Link(destination: URL(string: "https://brapi.dev")!) {
                LabeledContent("Dados de mercado") {
                    Text("brapi.dev")
                        .foregroundStyle(Color.tqAccentGreen)
                }
            }
        }
    }
}
