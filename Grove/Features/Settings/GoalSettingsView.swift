import SwiftUI
import SwiftData
import GroveDomain
import GroveServices

struct GoalSettingsView: View {
    let settings: UserSettings
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query(sort: \Holding.ticker) private var holdings: [Holding]
    @State private var viewModel = GoalSettingsViewModel()

    var body: some View {
        Form {
            gaugeExplainerSection
            freedomPlanSection
            amountsSection
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Goals")
        .onAppear {
            viewModel.bind(settings: settings, displayCurrency: displayCurrency, rates: rates)
        }
        .onChange(of: displayCurrency) { _, new in
            viewModel.displayCurrency = new
        }
        .onDisappear {
            viewModel.markPlanCompleted()
        }
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            }
        }
        #endif
    }

    // MARK: - Gauge Explainer

    private var gaugeExplainerSection: some View {
        let breakdown = viewModel.monthlyNetByClass(holdings: holdings)
        return Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("This month, net of taxes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: breakdown.totalNet.formatted(in: displayCurrency, using: rates))
                    .font(.system(size: Theme.FontSize.title2, weight: .bold))
                    .foregroundStyle(Color.tqAccentGreen)
                Text("This is the number in the center of the gauge — paid plus projected dividends for the current month, after Brazilian taxes.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Theme.Spacing.xs)

            if breakdown.details.isEmpty {
                Text("Add holdings or import dividends to see the breakdown.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(breakdown.details) { detail in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: detail.assetClass.icon)
                            .font(.callout)
                            .foregroundStyle(detail.assetClass.color)
                            .frame(width: 22)
                        Text(detail.assetClass.displayName)
                        Spacer()
                        Text(verbatim: detail.net.formatted(in: displayCurrency, using: rates))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }

            NavigationLink {
                IncomeHistoryView()
            } label: {
                Label("See income history", systemImage: "chart.bar.fill")
            }
        } header: {
            Text("Reading the gauge")
        } footer: {
            Text("The ring fills as this monthly income approaches your Freedom Number below.")
        }
    }

    // MARK: - Freedom Plan

    private var freedomPlanSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Freedom number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: viewModel.freedomNumber.formatted(in: displayCurrency, using: rates))
                    .font(.system(size: Theme.FontSize.title2, weight: .bold))
                    .foregroundStyle(Color.tqAccentGreen)
                Text("Your monthly net income target, derived from your cost of living and lifestyle mode.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Theme.Spacing.xs)

            Picker("Lifestyle at FI", selection: Binding(
                get: { settings.fiIncomeMode },
                set: { viewModel.setIncomeMode($0) }
            )) {
                Text("Cover today's life · 1×").tag(FIIncomeMode.essentials)
                Text("Comfortable · 1.5×").tag(FIIncomeMode.lifestyle)
                Text("Comfortable + buffer · 2×").tag(FIIncomeMode.lifestylePlusBuffer)
            }

            Stepper(
                value: Binding(
                    get: { settings.targetFIYear == 0 ? viewModel.fiYearRange.lowerBound + 20 : settings.targetFIYear },
                    set: { viewModel.setTargetFIYear($0) }
                ),
                in: viewModel.fiYearRange
            ) {
                let year = settings.targetFIYear == 0 ? viewModel.fiYearRange.lowerBound + 20 : settings.targetFIYear
                LabeledContent("Target FI year", value: "\(year)")
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                LabeledContent("BRL share of FI income") {
                    Text(verbatim: "\(Int(NSDecimalNumber(decimal: settings.fiCurrencyMixBRLPercent).doubleValue))%")
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { NSDecimalNumber(decimal: settings.fiCurrencyMixBRLPercent).doubleValue },
                        set: { viewModel.setCurrencyMixBRLPercent(Decimal($0)) }
                    ),
                    in: 0...100,
                    step: 5
                )
            }
        } header: {
            Text("Freedom Plan")
        } footer: {
            Text("Edit any of these and your Freedom Number recalculates instantly.")
        }
    }

    // MARK: - Amounts

    private var amountsSection: some View {
        let cost = viewModel.decimalBinding(
            for: \.monthlyCostOfLiving,
            currency: \.monthlyCostOfLivingCurrency
        )
        let capacity = viewModel.decimalBinding(
            for: \.monthlyContributionCapacity,
            currency: \.monthlyContributionCapacityCurrency
        )
        return Section {
            TQCurrencyField(
                title: "Monthly Cost of Living",
                currency: displayCurrency,
                value: Binding(get: cost.get, set: cost.set)
            )

            TQCurrencyField(
                title: "Monthly Contribution Capacity",
                currency: displayCurrency,
                value: Binding(get: capacity.get, set: capacity.set)
            )
        } header: {
            Text("Amounts")
        } footer: {
            Text("Edited in your display currency; stored amounts are FX-converted for display.")
        }
    }

}
