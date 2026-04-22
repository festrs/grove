import SwiftUI
import SwiftData

struct RebalancingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = RebalancingViewModel()
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    inputCard
                    if viewModel.hasCalculated {
                        if viewModel.suggestions.isEmpty {
                            noSuggestionsCard
                        } else {
                            suggestionsCard
                            registerButton
                        }
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Aportar")
        }
    }

    private var inputCard: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Quanto voce vai investir este mes?")
                    .font(.headline)

                HStack {
                    Text("R$")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    TextField("5.000", text: $viewModel.investmentAmountText)
                        .font(.title)
                        .fontWeight(.bold)
                        .keyboardType(.decimalPad)
                }

                Button {
                    viewModel.calculate(modelContext: modelContext)
                } label: {
                    Text("Calcular distribuicao")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.tqAccentGreen)
                .disabled(viewModel.investmentAmount <= 0)
            }
        }
    }

    private var noSuggestionsCard: some View {
        TQCard {
            TQEmptyState(
                icon: "slider.horizontal.3",
                title: "Configure a alocacao",
                message: "Defina a alocacao por classe no menu Editar Portfolio para receber sugestoes de aporte."
            )
        }
    }

    private var suggestionsCard: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Text("Sugestao de aporte")
                        .font(.headline)
                    Spacer()
                    Text(viewModel.totalAllocated.formattedBRL())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(viewModel.suggestions) { suggestion in
                    RebalancingResultRow(suggestion: suggestion)
                    if suggestion.id != viewModel.suggestions.last?.id {
                        Divider()
                    }
                }

                let remainder = viewModel.investmentAmount - viewModel.totalAllocated
                if remainder > 0 {
                    HStack {
                        Text("Sobra (fracionamento)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(remainder.formattedBRL())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var registerButton: some View {
        Button {
            showingConfirmation = true
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Registrar aporte")
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.tqAccentGreen)
        .confirmationDialog(
            "Confirmar aporte?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Registrar") {
                viewModel.registerContributions(modelContext: modelContext)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("As quantidades serao adicionadas ao seu portfolio. Lembre-se de executar as ordens na sua corretora.")
        }
    }
}

#Preview {
    RebalancingView()
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self], inMemory: true)
}
