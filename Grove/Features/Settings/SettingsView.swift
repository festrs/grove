import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query private var allSettings: [UserSettings]
    @Query private var holdings: [Holding]
    @State private var showingResetAlert = false

    private var settings: UserSettings? { allSettings.first }

    private var portfolioValue: Money {
        let repo = PortfolioRepository(modelContext: modelContext)
        return repo.computeSummary(
            holdings: holdings,
            displayCurrency: displayCurrency,
            rates: rates
        ).totalValue
    }

    var body: some View {
        NavigationStack {
            Form {
                if let settings {
                    portfolioInfoSection
                    displayCurrencySection(settings: settings)
                    goalsSection(settings: settings)
                    rebalancingSection(settings: settings)
                    // TODO: Enable when push notifications are ready
                    // NotificationSettingsSection()
                    PremiumSection(settings: settings)
                    AboutSection()
                    dangerSection
                }
            }
            .navigationTitle("Settings")
            .task { ensureSettings() }
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
            LabeledContent("Assets", value: "\(holdings.count)")
            LabeledContent("Total Value", value: portfolioValue.formatted())
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
                    settings?.hasCompletedOnboarding = false
                    try? modelContext.save()
                }
            } message: {
                Text("You will be taken to the initial flow. Your data will be preserved.")
            }
        }
    }

    /// Bootstrap a UserSettings record if onboarding never ran (defensive —
    /// the onboarding flow normally seeds it). Without this, Settings would
    /// render an empty Form on a fresh install.
    private func ensureSettings() {
        guard allSettings.isEmpty else { return }
        modelContext.insert(UserSettings())
        try? modelContext.save()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, GroveDomain.Transaction.self, UserSettings.self], inMemory: true)
}
