import SwiftUI
import SwiftData
import GroveDomain

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @State private var viewModel = SettingsViewModel()
    @State private var showingResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                if let settings = viewModel.settings {
                    portfolioInfoSection
                    displayCurrencySection(settings: settings)
                    goalsSection(settings: settings)
                    rebalancingSection(settings: settings)
                    // TODO: Enable when push notifications are ready
                    // NotificationSettingsSection()
                    PremiumSection()
                    AboutSection()
                    dangerSection
                }
            }
            .navigationTitle("Settings")
            .task {
                viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
            }
        }
    }

    private func goalsSection(settings: UserSettings) -> some View {
        Section {
            NavigationLink {
                GoalSettingsView(settings: settings)
            } label: {
                Label("Goals", systemImage: "target")
            }
        }
    }

    private func rebalancingSection(settings: UserSettings) -> some View {
        @Bindable var settings = settings
        return Section("Rebalancing") {
            Stepper(
                "Recommendations per investment: \(settings.recommendationCount)",
                value: $settings.recommendationCount,
                in: 1...10
            )
        }
    }

    private var portfolioInfoSection: some View {
        Section("Portfolio") {
            NavigationLink {
                AllocationSettingsView()
            } label: {
                HStack {
                    Label("Allocation by Class", systemImage: "chart.pie")
                    Spacer()
                }
            }
            LabeledContent("Assets", value: "\(viewModel.holdingCount)")
            LabeledContent(
                "Total Value",
                value: viewModel.portfolioValue.formatted()
            )
        }
    }

    private func displayCurrencySection(settings: UserSettings) -> some View {
        Section {
            Picker(
                "Display Currency",
                selection: Binding(
                    get: { settings.preferredCurrency },
                    set: { settings.preferredCurrency = $0 }
                )
            ) {
                ForEach(Currency.allCases) { currency in
                    Text(currency.displayName).tag(currency)
                }
            }
        } header: {
            Text("Currency")
        } footer: {
            Text("Used for portfolio totals and passive-income figures. Per-asset prices keep the asset's own currency.")
        }
    }

    private var dangerSection: some View {
        Section {
            Button("Restart Onboarding", role: .destructive) {
                showingResetAlert = true
            }
            .alert("Restart Onboarding?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Restart", role: .destructive) {
                    viewModel.resetOnboarding()
                }
            } message: {
                Text("You will be taken to the initial flow. Your data will be preserved.")
            }
        }
    }

}

#Preview {
    SettingsView()
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self], inMemory: true)
}
