#if DEBUG
import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories

/// Debug-only preview of a candidate "all portfolios at once" overview.
/// Lets us A/B the proposed list (consolidated hero + one row per
/// portfolio with totals) against today's reality (a name-only selector
/// with no aggregate view at all).
///
/// Intentional scope limits:
/// - Drill-in pushes a placeholder, not the real PortfolioView (would
///   require plumbing an "active portfolio" override end-to-end).
/// - No edit/reorder/archive — just viewing.
/// - Computes per-portfolio summaries inline so production
///   `PortfolioRepository` stays untouched until we commit to ship.
struct PortfoliosOverviewPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query private var portfolios: [Portfolio]
    @Query private var holdings: [Holding]
    @Query private var settingsList: [UserSettings]

    @State private var mode: Mode = .overview

    enum Mode: String, CaseIterable, Identifiable {
        case overview      // proposed
        case selectorOnly  // mirrors today's PortfolioSelectorMenu in isolation
        var id: String { rawValue }
        var label: String {
            switch self {
            case .overview:     "Overview (proposed)"
            case .selectorOnly: "Selector only (today)"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            modePicker
            Divider().opacity(0.4)

            switch mode {
            case .overview:     overviewLayout
            case .selectorOnly: selectorOnlyLayout
            }
        }
        .background(Color.tqBackground)
        .navigationTitle("Portfolios Overview")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { m in Text(m.label).tag(m) }
            }
            .pickerStyle(.segmented)

            Text(mode == .overview
                 ? "Each portfolio gets a row with its own total, income, and allocation health. Tap to drill in."
                 : "What you see today: a name-only menu. No way to compare totals without switching.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Variant A: proposed overview

    private var overviewLayout: some View {
        Group {
            if portfolios.isEmpty {
                emptyState
            } else if portfolios.count == 1 {
                singlePortfolioState
            } else {
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        consolidatedHero
                        portfolioList
                    }
                    .padding(Theme.Spacing.md)
                }
            }
        }
    }

    // MARK: - Variant B: today's selector in isolation

    private var selectorOnlyLayout: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer().frame(height: Theme.Spacing.lg)

            HStack {
                PortfolioSelectorMenu(
                    portfolios: portfolios,
                    selected: portfolios.first,
                    onSelect: { _ in }
                )
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)

            Text("That's it. To see another portfolio's total you must tap the menu, switch, and wait for the screen to reload.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Spacing.md)

            Spacer()
        }
    }

    // MARK: - Hero (consolidated totals)

    private var consolidatedHero: some View {
        let summary = consolidatedSummary
        return TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("ALL PORTFOLIOS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)

                Text(summary.totalValue.formatted())
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: Theme.Spacing.lg) {
                    heroStat(
                        label: String(localized: "Monthly net income"),
                        value: summary.monthlyIncomeNet.formatted(),
                        color: .tqAccentGreen
                    )
                    heroStat(
                        label: String(localized: "Portfolios"),
                        value: "\(portfolios.count)",
                        color: .primary
                    )
                    heroStat(
                        label: String(localized: "Holdings"),
                        value: "\(holdings.count)",
                        color: .primary
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func heroStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }

    // MARK: - Per-portfolio rows

    private var portfolioList: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(portfolios, id: \.persistentModelID) { portfolio in
                NavigationLink {
                    PortfolioDetailPlaceholder(portfolio: portfolio)
                } label: {
                    portfolioRow(portfolio)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func portfolioRow(_ portfolio: Portfolio) -> some View {
        let summary = summary(for: portfolio)
        let health = allocationHealth(for: summary)

        return TQCard {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                // Identity
                ZStack {
                    Circle()
                        .fill(Color.tqAccentGreen.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.tqAccentGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: portfolio.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(portfolio.holdings.count) holdings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: Theme.Spacing.sm)

                // Numerics — right-aligned column
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: summary.totalValue.formatted())
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                    Text("\(summary.monthlyIncomeNet.formatted())/mo")
                        .font(.caption)
                        .foregroundStyle(Color.tqAccentGreen)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                allocationHealthPill(health)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Allocation health

    private enum HealthState {
        case balanced, attention, rebalance, unset
        var label: LocalizedStringKey {
            switch self {
            case .balanced:  "Balanced"
            case .attention: "Attention"
            case .rebalance: "Rebalance"
            case .unset:     "No target"
            }
        }
        var color: Color {
            switch self {
            case .balanced:  .tqAccentGreen
            case .attention: .tqWarning
            case .rebalance: .tqNegative
            case .unset:     .gray
            }
        }
        var icon: String {
            switch self {
            case .balanced:  "checkmark.circle.fill"
            case .attention: "exclamationmark.circle.fill"
            case .rebalance: "arrow.triangle.2.circlepath"
            case .unset:     "circle.dashed"
            }
        }
    }

    private func allocationHealth(for summary: PortfolioSummary) -> HealthState {
        let withTargets = summary.allocationByClass.filter { $0.targetPercent > 0 }
        guard !withTargets.isEmpty else { return .unset }
        let maxDrift = withTargets.map { abs(NSDecimalNumber(decimal: $0.drift).doubleValue) }.max() ?? 0
        switch maxDrift {
        case ..<2:  return .balanced
        case ..<5:  return .attention
        default:    return .rebalance
        }
    }

    private func allocationHealthPill(_ state: HealthState) -> some View {
        HStack(spacing: 4) {
            Image(systemName: state.icon)
                .font(.system(size: 10, weight: .bold))
            Text(state.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(state.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(state.color.opacity(0.15), in: Capsule())
    }

    // MARK: - Summaries

    /// One PortfolioSummary per portfolio, computed inline using the
    /// existing `computeSummary(holdings:)` helper. Kept in the prototype
    /// so production `PortfolioRepository` doesn't grow new API until we
    /// commit to ship this surface.
    private func summary(for portfolio: Portfolio) -> PortfolioSummary {
        let repo = PortfolioRepository(modelContext: modelContext)
        return repo.computeSummary(
            holdings: portfolio.holdings,
            classAllocations: settingsList.first?.classAllocations ?? [:],
            displayCurrency: displayCurrency,
            rates: rates
        )
    }

    private var consolidatedSummary: PortfolioSummary {
        let repo = PortfolioRepository(modelContext: modelContext)
        return repo.computeSummary(
            holdings: holdings,
            classAllocations: settingsList.first?.classAllocations ?? [:],
            displayCurrency: displayCurrency,
            rates: rates
        )
    }

    // MARK: - Edge states

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Nenhum portfolio ainda")
                .font(.headline)
            Text("Crie um portfolio para começar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var singlePortfolioState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            Image(systemName: "briefcase")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Você só tem um portfolio")
                .font(.headline)
            Text("Em produção, o app pularia esta tela e abriria '\(portfolios.first?.name ?? "")' direto.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
            Spacer()
        }
    }
}

// MARK: - Drill-in placeholder

private struct PortfolioDetailPlaceholder: View {
    let portfolio: Portfolio

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "arrow.right.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Em produção: PortfolioView para")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(portfolio.name)
                .font(.title3.weight(.semibold))
            Text("\(portfolio.holdings.count) ativos")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tqBackground)
        .navigationTitle(portfolio.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self,
        configurations: config
    )
    let ctx = container.mainContext

    let aposentadoria = Portfolio(name: "Aposentadoria")
    let filhos = Portfolio(name: "Filhos")
    let curtoPrazo = Portfolio(name: "Curto prazo")
    [aposentadoria, filhos, curtoPrazo].forEach(ctx.insert)

    let settings = UserSettings(hasCompletedOnboarding: true)
    settings.classAllocations = [
        .acoesBR: 25, .fiis: 25, .usStocks: 20,
        .reits: 10, .crypto: 10, .rendaFixa: 10
    ]
    ctx.insert(settings)

    for h in [Holding.itub3, .wege3, .btlg11] { h.portfolio = aposentadoria; ctx.insert(h) }
    for h in [Holding.knri11, .aapl] { h.portfolio = filhos; ctx.insert(h) }
    for h in [Holding.vti, .o, .btc, .ipca2035] { h.portfolio = curtoPrazo; ctx.insert(h) }

    return NavigationStack {
        PortfoliosOverviewPreviewView()
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
#endif
