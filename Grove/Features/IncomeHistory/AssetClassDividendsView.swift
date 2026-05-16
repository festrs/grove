import SwiftUI
import SwiftData
import GroveDomain

/// Drilldown from `IncomeHistoryView`: lists every holding in a given asset
/// class together with its dividend payments. Surfaces the actual income
/// behind the per-class projection so users can verify which tickers are
/// generating the cash.
struct AssetClassDividendsView: View {
    let assetClass: AssetClassType
    let window: IncomeWindow
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query private var holdings: [Holding]
    @State private var viewModel = AssetClassDividendsViewModel()

    init(assetClass: AssetClassType, window: IncomeWindow = .year) {
        self.assetClass = assetClass
        self.window = window
        let raw = assetClass.rawValue
        _holdings = Query(
            filter: #Predicate<Holding> { $0.assetClassRaw == raw },
            sort: \.ticker
        )
    }

    private var holdingsWithPayments: [Holding] {
        holdings.filter { !$0.classifiedDividends(in: window).isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }
                if holdingsWithPayments.isEmpty {
                    TQEmptyState(
                        icon: "tray",
                        title: "No dividends yet",
                        message: "Pull to refresh and we'll fetch payment history for these tickers from the backend."
                    )
                } else {
                    ForEach(holdingsWithPayments, id: \.persistentModelID) { holding in
                        holdingCard(holding)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: Theme.Layout.maxContentWidth)
        }
        .navigationTitle(navigationTitle)
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

    private var navigationTitle: String {
        let suffix: String? = {
            switch window {
            case .day: return "Today"
            case .week: return "This Week"
            case .month: return "This Month"
            case .year: return "This Year"
            case .custom: return nil
            }
        }()
        guard let suffix else { return assetClass.displayName }
        return "\(assetClass.displayName) · \(suffix)"
    }

    private func holdingCard(_ holding: Holding) -> some View {
        let rows = holding.classifiedDividends(in: window)
        let paidTotal = holding.paidIncome(in: window, displayCurrency: displayCurrency, rates: rates)
        let projectedTotal = holding.projectedIncome(in: window, displayCurrency: displayCurrency, rates: rates)
        let paidCount = rows.filter { $0.kind == .paid }.count
        let projectedCount = rows.filter { $0.kind == .projected }.count

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
                        Text(paidTotal.formatted())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.tqAccentGreen)
                        if projectedTotal.amount > 0 {
                            Text("+ \(projectedTotal.formatted()) projected")
                                .font(.caption2)
                                .foregroundStyle(Color.tqAccentGreen.opacity(0.8))
                        }
                        cardSubtitle(paidCount: paidCount, projectedCount: projectedCount)
                    }
                }
                Divider()
                ForEach(rows) { row in
                    dividendRow(row)
                }
            }
        }
    }

    private func cardSubtitle(paidCount: Int, projectedCount: Int) -> some View {
        let parts: [String] = {
            var p: [String] = []
            if paidCount > 0 { p.append("\(paidCount) paid") }
            if projectedCount > 0 { p.append("\(projectedCount) projected") }
            if p.isEmpty { p.append("0 payments") }
            return p
        }()
        return Text(parts.joined(separator: " · "))
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func dividendRow(_ row: ClassifiedDividend) -> some View {
        let kind = row.kind
        let d = row.payment
        let badge: (label: String, opacity: Double)? = {
            switch kind {
            case .paid: return nil
            case .projected: return ("projected", 0.85)
            }
        }()
        let amountColor: Color = kind == .paid ? Color.tqAccentGreen : Color.secondary
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(d.paymentDate.formatted(.dateTime.day().month().year()))
                        .font(.subheadline)
                    if let badge {
                        Text(badge.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text("\(d.amountPerShareMoney.formatted()) / share")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(d.totalAmountMoney.formatted())
                    .font(.subheadline)
                    .foregroundStyle(amountColor)
                if d.withholdingTax > 0 {
                    Text("net \(d.netAmountMoney.formatted())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .opacity(badge?.opacity ?? 1)
    }
}

#Preview {
    NavigationStack {
        AssetClassDividendsView(assetClass: .fiis, window: .month)
            .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, GroveDomain.Transaction.self, UserSettings.self], inMemory: true)
    }
}
