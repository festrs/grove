import SwiftUI
import SwiftData

struct IncomeHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService
    @Environment(\.backendService) private var backendService
    @State private var viewModel = IncomeHistoryViewModel()

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // Summary cards: side-by-side on wide screens
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 280), spacing: Theme.Spacing.md)],
                    spacing: Theme.Spacing.md
                ) {
                    annualSummaryCard
                    monthlySummaryCard
                }

                // Asset class breakdown: grid on wide screens
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
        .navigationTitle("Renda Passiva")
        .refreshable {
            await syncService.syncAll(modelContext: modelContext, backendService: backendService)
            viewModel.loadData(modelContext: modelContext)
        }
        .task {
            viewModel.loadData(modelContext: modelContext)
        }
        .onChange(of: syncService.isSyncing) { _, syncing in
            if !syncing { viewModel.loadData(modelContext: modelContext) }
        }
    }

    private var annualSummaryCard: some View {
        TQCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Renda anual estimada")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.totalAnnualBRL.formattedBRL())
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
                    Text("Renda mensal estimada")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.monthlyIncomeBRL.formattedBRL())
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Spacer()
                Text("/mes").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func assetClassCard(_ detail: TaxBreakdownDetail) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Circle().fill(detail.assetClass.color).frame(width: 10, height: 10)
                    Text(detail.assetClass.displayName).font(.headline)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(detail.gross.formattedBRL())
                            .font(.subheadline).fontWeight(.semibold)
                        if detail.tax > 0 {
                            Text("-\(detail.tax.formattedBRL()) IR")
                                .font(.caption2).foregroundStyle(.red)
                        }
                        Text(detail.net.formattedBRL())
                            .font(.caption).foregroundStyle(Color.tqAccentGreen)
                    }
                }
            }
        }
    }
}

#Preview {
    IncomeHistoryView()
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self], inMemory: true)
}
