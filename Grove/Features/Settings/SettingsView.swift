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
            NavigationLink {
                AllocationSettingsView()
            } label: {
                HStack {
                    Label("Alocacao por classe", systemImage: "chart.pie")
                    Spacer()
                }
            }
            LabeledContent("Ativos", value: "\(viewModel.holdingCount)")
            LabeledContent("Valor total", value: viewModel.portfolioValue.formattedBRL())
        }
    }

    private var dangerSection: some View {
        Section {
            #if DEBUG
            Button("Carregar dados de teste") {
                loadSampleData()
            }
            #endif

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

    #if DEBUG
    private func loadSampleData() {
        // Use existing portfolio or create one
        let descriptor = FetchDescriptor<Portfolio>(sortBy: [SortDescriptor(\.createdAt)])
        let portfolio: Portfolio
        if let existing = try? modelContext.fetch(descriptor).first {
            portfolio = existing
        } else {
            portfolio = Portfolio(name: "Meu Portfolio")
            modelContext.insert(portfolio)
        }
        // Set global allocations on UserSettings
        if let settings = (try? modelContext.fetch(FetchDescriptor<UserSettings>()))?.first {
            settings.classAllocations = [
                .acoesBR: 27, .fiis: 15, .usStocks: 28,
                .reits: 10, .crypto: 5, .rendaFixa: 5,
            ]
        }

        // Only add holdings that don't already exist
        let existingTickers = Set(portfolio.holdings.map(\.ticker))
        let calendar = Calendar.current
        for (i, holding) in Holding.allSamples.enumerated() {
            if !existingTickers.contains(holding.ticker) {
                modelContext.insert(holding)
                holding.portfolio = portfolio

                // Create initial buy contribution — contributions are the source of truth
                if holding.quantity > 0 {
                    let buyDate = calendar.date(byAdding: .month, value: -(6 + i % 4), to: .now) ?? .now
                    let contribution = Contribution(
                        date: buyDate,
                        amount: holding.quantity * holding.averagePrice,
                        shares: holding.quantity,
                        pricePerShare: holding.averagePrice
                    )
                    modelContext.insert(contribution)
                    contribution.holding = holding
                }
            }
        }

        // Ensure settings
        let settingsDesc = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(settingsDesc).first {
            settings.hasCompletedOnboarding = true
            settings.monthlyIncomeGoal = 10_000
        } else {
            let settings = UserSettings(
                monthlyIncomeGoal: 10_000,
                monthlyCostOfLiving: 15_000,
                hasCompletedOnboarding: true
            )
            modelContext.insert(settings)
        }

        try? modelContext.save()
        viewModel.loadData(modelContext: modelContext)
    }
    #endif
}

#Preview {
    SettingsView()
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self], inMemory: true)
}
