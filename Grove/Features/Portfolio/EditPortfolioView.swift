import SwiftUI
import SwiftData

struct EditPortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var portfolio: Portfolio
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Nome") {
                    TextField("Nome do portfolio", text: $portfolio.name)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack { Spacer(); Text("Excluir portfolio"); Spacer() }
                    }
                }
            }
            .navigationTitle("Editar portfolio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .alert("Excluir portfolio", isPresented: $showDeleteAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Excluir", role: .destructive) {
                    modelContext.delete(portfolio)
                    dismiss()
                }
            } message: {
                Text("Todos os ativos deste portfolio serao removidos.")
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 400)
        #endif
    }
}
