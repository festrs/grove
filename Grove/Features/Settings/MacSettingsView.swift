#if os(macOS)
import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories

/// macOS Settings window. Mirrors the System Settings pattern: a `TabView`
/// with fixed-size grouped Forms, no NavigationStack, no NavigationLinks.
struct MacSettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }

            PortfolioSettingsTab()
                .tabItem { Label("Portfolio", systemImage: "chart.pie") }

            GoalsSettingsTab()
                .tabItem { Label("Goals", systemImage: "target") }

            RebalancingSettingsTab()
                .tabItem { Label("Rebalancing", systemImage: "arrow.triangle.2.circlepath") }

            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .scenePadding()
        .frame(width: 560, height: 460)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query private var settings: [UserSettings]
    @State private var viewModel = SettingsViewModel()
    @State private var showingResetAlert = false

    var body: some View {
        Form {
            if let s = settings.first {
                Section {
                    Picker("Display Currency", selection: Binding(
                        get: { s.preferredCurrency },
                        set: { s.preferredCurrency = $0 }
                    )) {
                        ForEach(Currency.allCases) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                } footer: {
                    Text("Used for portfolio totals and passive-income figures. Per-asset prices keep the asset's own currency.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Restart Onboarding…", role: .destructive) {
                    showingResetAlert = true
                }
            } footer: {
                Text("Returns to the initial flow. Your data will be preserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task {
            viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
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

// MARK: - Portfolio (stats + allocation)

private struct PortfolioSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query private var holdings: [Holding]
    @State private var allocationVM = AllocationSettingsViewModel()

    private var totalValue: Money {
        let repo = PortfolioRepository(modelContext: modelContext)
        let summary = repo.computeSummary(holdings: holdings, displayCurrency: displayCurrency, rates: rates)
        return summary.totalValue
    }

    var body: some View {
        Form {
            Section("Overview") {
                LabeledContent("Assets", value: "\(holdings.count)")
                LabeledContent("Total Value", value: totalValue.formatted())
            }

            Section {
                ForEach(AssetClassType.allCases) { cls in
                    HStack {
                        Circle()
                            .fill(cls.color)
                            .frame(width: 10, height: 10)
                        Text(cls.displayName)
                        Spacer()
                        Text("\(Int(allocationVM.weights[cls] ?? 0))%")
                            .monospacedDigit()
                            .foregroundStyle((allocationVM.weights[cls] ?? 0) > 0 ? .primary : .secondary)
                            .frame(width: 44, alignment: .trailing)
                        Stepper("", value: Binding(
                            get: { allocationVM.weights[cls] ?? 0 },
                            set: { allocationVM.setWeight($0, for: cls) }
                        ), in: 0...100, step: 1)
                        .labelsHidden()
                    }
                }

                HStack {
                    Text("Total").fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(allocationVM.total))%")
                        .monospacedDigit()
                        .fontWeight(.bold)
                        .foregroundStyle(allocationVM.isValid ? Color.tqAccentGreen : Color.tqNegative)
                }
            } header: {
                HStack {
                    Text("Allocation by Class")
                    Spacer()
                    if allocationVM.hasChanges {
                        Button("Save") {
                            allocationVM.save(modelContext: modelContext)
                        }
                        .controlSize(.small)
                        .disabled(!allocationVM.isValid)
                    }
                }
            } footer: {
                Text("Define how much of your total assets each class should represent. Must sum to 100%.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { allocationVM.load(modelContext: modelContext) }
    }
}

// MARK: - Goals

private struct GoalsSettingsTab: View {
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query private var settings: [UserSettings]

    var body: some View {
        Form {
            if let s = settings.first {
                @Bindable var bound = s
                Section {
                    TQCurrencyField(
                        title: "Monthly Passive Income",
                        currency: displayCurrency,
                        value: binding(for: \.monthlyIncomeGoal, currency: \.monthlyIncomeGoalCurrency, on: bound)
                    )
                    TQCurrencyField(
                        title: "Monthly Cost of Living",
                        currency: displayCurrency,
                        value: binding(for: \.monthlyCostOfLiving, currency: \.monthlyCostOfLivingCurrency, on: bound)
                    )
                    TQCurrencyField(
                        title: "Emergency Reserve (Target)",
                        currency: displayCurrency,
                        value: binding(for: \.emergencyReserveTarget, currency: \.emergencyReserveTargetCurrency, on: bound)
                    )
                    TQCurrencyField(
                        title: "Emergency Reserve (Current)",
                        currency: displayCurrency,
                        value: binding(for: \.emergencyReserveCurrent, currency: \.emergencyReserveCurrentCurrency, on: bound)
                    )
                } footer: {
                    Text("Edited in your display currency; stored amounts are FX-converted for display.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding(
        for amount: ReferenceWritableKeyPath<UserSettings, Decimal>,
        currency: ReferenceWritableKeyPath<UserSettings, Currency>,
        on settings: UserSettings
    ) -> Binding<Decimal> {
        Binding<Decimal>(
            get: {
                let stored = Money(amount: settings[keyPath: amount], currency: settings[keyPath: currency])
                return stored.converted(to: displayCurrency, using: rates).amount
            },
            set: { newValue in
                settings[keyPath: amount] = newValue
                settings[keyPath: currency] = displayCurrency
            }
        )
    }
}

// MARK: - Rebalancing

private struct RebalancingSettingsTab: View {
    @Query private var settings: [UserSettings]

    var body: some View {
        Form {
            if let s = settings.first {
                @Bindable var bound = s
                Section {
                    Stepper(
                        "Recommendations per investment: \(bound.recommendationCount)",
                        value: $bound.recommendationCount,
                        in: 1...10
                    )
                } footer: {
                    Text("How many holdings to surface in each Invest cycle.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About (plan + version + credits)

private struct AboutSettingsTab: View {
    var body: some View {
        Form {
            PremiumSection()
            AboutSection()
        }
        .formStyle(.grouped)
    }
}
#endif
