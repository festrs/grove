import SwiftUI
import SwiftData

struct EditPortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var portfolio: Portfolio
    @State private var showDeleteAlert = false
    @State private var weights: [AssetClassType: Double] = [:]

    private var isValid: Bool {
        let total = weights.values.reduce(0, +)
        return abs(total - 100) < 0.5
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nome") {
                    TextField("Nome do portfolio", text: $portfolio.name)
                }

                Section {
                    WeightInputOptionA(weights: $weights, holdings: portfolio.holdings)

                    if !isValid {
                        Text("A alocacao deve somar 100%.")
                            .font(.caption)
                            .foregroundStyle(Color.tqNegative)
                    }
                } header: {
                    Text("Alocacao por classe")
                } footer: {
                    Text("Define quanto do portfolio cada classe deve representar. Deve somar 100%.")
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        portfolio.classAllocations = weights
                        dismiss()
                    }
                    .disabled(!isValid)
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
            .onAppear { weights = portfolio.classAllocations }
        }
    }
}
