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
    @Query private var holdings: [Holding]
    @State private var selectedWindow: IncomeWindow = .year

    private static let displayedWindows: [IncomeWindow] = [.day, .week, .month, .year]

    private var summaries: [IncomeWindowSummary] {
        Self.displayedWindows.map { window in
            IncomeAggregator.summary(
                holdings: holdings, window: window,
                in: displayCurrency, rates: rates
            )
        }
    }

    private var byClass: [PassiveIncomeByClass] {
        IncomeAggregator.byClass(
            holdings: holdings, window: selectedWindow,
            in: displayCurrency, rates: rates
        )
    }

    private var taxBreakdown: MoneyTaxBreakdown? {
        let grossByClass = Dictionary(uniqueKeysWithValues: byClass.map { ($0.assetClass, $0.total) })
        guard !grossByClass.isEmpty else { return nil }
        return TaxCalculator.taxBreakdown(
            grossByClass: grossByClass,
            displayCurrency: displayCurrency,
            rates: rates
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                windowGrid
                if let breakdown = taxBreakdown {
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
            if syncService.isSyncing {
                ProgressView().controlSize(.small)
            } else {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .disabled(syncService.isSyncing)
        .help("Sync dividends from backend for all holdings")
    }

    private func refresh() async {
        await syncService.syncAll(modelContext: modelContext, backendService: backendService)
        // Explicit user tap on the dividends screen — bypass the once-per-day
        // gate and pull fresh records so the May/this-month rows land even if
        // the background sync already ran today.
        try? await syncService.syncDividends(modelContext: modelContext, backendService: backendService)
        try? modelContext.save()
    }

    /// Day / Week / Month / Year cards. Tapping selects the window for the
    /// per-class breakdown below.
    private var windowGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: Theme.Spacing.sm)],
            spacing: Theme.Spacing.sm
        ) {
            ForEach(summaries, id: \.window) { summary in
                windowCard(summary)
            }
        }
    }

    private func windowCard(_ summary: IncomeWindowSummary) -> some View {
        let isSelected = summary.window == selectedWindow
        return Button {
            selectedWindow = summary.window
        } label: {
            TQCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(label(for: summary.window))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(summary.total.formatted())
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.tqAccentGreen)
                    HStack(spacing: 4) {
                        Text("Paid \(summary.paid.formatted())")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if summary.projected.amount > 0 {
                            Text("· Proj \(summary.projected.formatted())")
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.card)
                    .stroke(isSelected ? Color.tqAccentGreen : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func label(for window: IncomeWindow) -> String {
        switch window {
        case .day: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .custom: return "Custom"
        }
    }

    private func assetClassCard(_ detail: MoneyTaxBreakdownDetail) -> some View {
        NavigationLink {
            AssetClassDividendsView(assetClass: detail.assetClass, window: selectedWindow)
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
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, GroveDomain.Transaction.self, UserSettings.self], inMemory: true)
}
