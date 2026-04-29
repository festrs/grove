import SwiftUI
import SwiftData
import GroveDomain
import GroveServices

struct IncomeHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService
    @Environment(\.backendService) private var backendService
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @State private var viewModel = IncomeHistoryViewModel()

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 280), spacing: Theme.Spacing.md)],
                    spacing: Theme.Spacing.md
                ) {
                    annualSummaryCard
                    monthlySummaryCard
                }

                if let breakdown = viewModel.taxBreakdown {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 280), spacing: Theme.Spacing.md)],
                        spacing: Theme.Spacing.md
                    ) {
                        ForEach(breakdown.details) { detail in
                            assetClassCard(detail)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: Theme.Layout.maxContentWidth)
        }
        .navigationTitle("Passive Income")
        .refreshable {
            await syncService.syncAll(modelContext: modelContext, backendService: backendService)
            viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
        }
        .task {
            viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
        }
        .onChange(of: syncService.isSyncing) { _, syncing in
            if !syncing { viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }
        }
    }

    private var annualSummaryCard: some View {
        TQCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Annual Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.totalAnnual.formatted())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.tqAccentGreen)
                }
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .font(.title)
                    .foregroundStyle(Color.tqAccentGreen.opacity(0.5))
            }
        }
    }

    private var monthlySummaryCard: some View {
        TQCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Monthly Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.monthlyIncome.formatted())
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Spacer()
                Text("/month").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func assetClassCard(_ detail: MoneyTaxBreakdownDetail) -> some View {
        NavigationLink {
            AssetClassDividendsView(assetClass: detail.assetClass)
        } label: {
            TQCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Circle().fill(detail.assetClass.color).frame(width: 10, height: 10)
                        Text(detail.assetClass.displayName).font(.headline)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(detail.gross.formatted())
                                .font(.subheadline).fontWeight(.semibold)
                            if detail.tax.amount > 0 {
                                Text("-\(detail.tax.formatted()) IR")
                                    .font(.caption2).foregroundStyle(.red)
                            }
                            Text(detail.net.formatted())
                                .font(.caption).foregroundStyle(Color.tqAccentGreen)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    IncomeHistoryView()
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self], inMemory: true)
}
