import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @State private var showingResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                if let settings = viewModel.settings {
                    GoalSettingsSection(settings: settings)
                    NotificationSettingsSection()
                    portfolioInfoSection
                    PremiumSection()
                    AboutSection()
                    dangerSection
                }
            }
            .navigationTitle("Ajustes")
            .task {
                viewModel.loadData(modelContext: modelContext)
            }
        }
    }

    private var portfolioInfoSection: some View {
        Section("Portfolio") {
            LabeledContent("Ativos", value: "\(viewModel.holdingCount)")
            LabeledContent("Valor total", value: viewModel.portfolioValue.formattedBRL())
        }
    }

    private var dangerSection: some View {
        Section {
            Button("Refazer onboarding", role: .destructive) {
                showingResetAlert = true
            }
            .alert("Refazer onboarding?", isPresented: $showingResetAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Refazer", role: .destructive) {
                    viewModel.resetOnboarding()
                }
            } message: {
                Text("Voce sera direcionado para o fluxo inicial. Seus dados serao mantidos.")
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self], inMemory: true)
}
