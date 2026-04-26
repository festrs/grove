import SwiftUI
import SwiftData

struct RebalancingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var viewModel = RebalancingViewModel()
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if sizeClass == .regular {
                    wideRebalancingLayout
                } else {
                    compactRebalancingLayout
                }
            }
            .navigationTitle("Invest")
        }
    }

    private var compactRebalancingLayout: some View {
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

    private var wideRebalancingLayout: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(spacing: Theme.Spacing.md) {
                inputCard
            }
            .frame(width: 360)

            if viewModel.hasCalculated {
                VStack(spacing: Theme.Spacing.md) {
                    if viewModel.suggestions.isEmpty {
                        noSuggestionsCard
                    } else {
                        suggestionsCard
                        AllocationComparisonChart(suggestions: viewModel.suggestions)
                        registerButton
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: Theme.Layout.maxContentWidth)
    }

    private var inputCard: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("How much will you invest this month?")
                    .font(.headline)

                HStack {
                    Text("R$")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    TextField("5.000", text: $viewModel.investmentAmountText)
                        .font(.title)
                        .fontWeight(.bold)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }

                Button {
                    viewModel.calculate(modelContext: modelContext)
                } label: {
                    Text("Calculate Distribution")
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
            switch viewModel.emptyReason {
            case .noAportarHoldings:
                TQEmptyState(
                    icon: "tray",
                    title: "No assets to invest in",
                    message: "Change the status of at least one asset to \"Invest\" on the portfolio screen."
                )
            case .noPortfolioValue:
                TQEmptyState(
                    icon: "chart.bar",
                    title: "Portfolio has no value",
                    message: "Register at least one purchase for rebalancing to work."
                )
            case .noAllocations:
                TQEmptyState(
                    icon: "slider.horizontal.3",
                    title: "Set up allocation",
                    message: "Define the allocation per class in Settings > Allocation to receive investment suggestions."
                )
            default:
                TQEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "No suggestions",
                    message: "Could not generate suggestions. Check your assets and allocations in Settings."
                )
            }
        }
    }

    private var suggestionsCard: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Text("Investment Suggestion")
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
                        Text("Remainder (fractional)")
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
                Text("Register Investment")
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.tqAccentGreen)
        .confirmationDialog(
            "Confirm investment?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Register") {
                viewModel.registerContributions(modelContext: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The quantities will be added to your portfolio. Remember to execute the orders at your brokerage.")
        }
    }
}

#Preview {
    RebalancingView()
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self], inMemory: true)
}
