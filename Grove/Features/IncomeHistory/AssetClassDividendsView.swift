import SwiftUI
import SwiftData
import GroveDomain

/// Drilldown from `IncomeHistoryView`: lists every holding in a given asset
/// class together with its dividend payments. Surfaces the actual income
/// behind the per-class projection so users can verify which tickers are
/// generating the cash.
struct AssetClassDividendsView: View {
    let assetClass: AssetClassType
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query private var holdings: [Holding]
    @State private var viewModel = AssetClassDividendsViewModel()

    init(assetClass: AssetClassType) {
        self.assetClass = assetClass
        let raw = assetClass.rawValue
        _holdings = Query(
            filter: #Predicate<Holding> { $0.assetClassRaw == raw },
            sort: \.ticker
        )
    }

    private var earningHoldings: [Holding] {
        holdings.filter { !$0.earnedDividends.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }
                if earningHoldings.isEmpty {
                    TQEmptyState(
                        icon: "tray",
                        title: "No dividends yet",
                        message: "Dividends for \(assetClass.displayName) will appear here once payments are recorded."
                    )
                } else {
                    ForEach(earningHoldings, id: \.persistentModelID) { holding in
                        holdingCard(holding)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: Theme.Layout.maxContentWidth)
        }
        .navigationTitle(assetClass.displayName)
        .refreshable { await refresh() }
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .primaryAction) { refreshToolbarButton }
            #else
            ToolbarItem(placement: .topBarTrailing) { refreshToolbarButton }
            #endif
        }
    }

    @ViewBuilder
    private var refreshToolbarButton: some View {
        Button {
            Task { await refresh() }
        } label: {
            if viewModel.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .disabled(viewModel.isRefreshing || holdings.isEmpty)
        .help("Fetch latest dividend data for these tickers")
    }

    private func refresh() async {
        await viewModel.refresh(
            symbols: holdings.map(\.ticker),
            assetClass: assetClass,
            modelContext: modelContext,
            backendService: backendService,
            syncService: syncService
        )
    }

    private func errorBanner(_ message: String) -> some View {
        TQCard {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func holdingCard(_ holding: Holding) -> some View {
        let dividends = holding.earnedDividends
        let total = dividends.map(\.totalAmountMoney).sum(in: displayCurrency, using: rates)

        return TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(holding.displayTicker)
                            .font(.headline)
                        Text(holding.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(total.formatted())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.tqAccentGreen)
                        Text("\(dividends.count) payment\(dividends.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
                ForEach(dividends, id: \.persistentModelID) { d in
                    dividendRow(d)
                }
            }
        }
    }

    private func dividendRow(_ d: DividendPayment) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(d.paymentDate.formatted(.dateTime.day().month().year()))
                    .font(.subheadline)
                Text("\(d.amountPerShareMoney.formatted()) / share")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(d.totalAmountMoney.formatted())
                    .font(.subheadline)
                    .foregroundStyle(Color.tqAccentGreen)
                if d.withholdingTax > 0 {
                    Text("net \(d.netAmountMoney.formatted())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AssetClassDividendsView(assetClass: .fiis)
            .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self], inMemory: true)
    }
}
