import SwiftUI
import SwiftData
import GroveDomain
import GroveRepositories

/// "All portfolios at once" overview — shown on iPad/Mac when the user has
/// more than one portfolio. Renders a consolidated hero (combined total +
/// monthly net income + counts) and one row per portfolio with totals,
/// monthly income, and an allocation-health pill so the user can scan
/// which portfolio needs attention without switching contexts.
///
/// Selection bubbles up via `onSelect`; the parent `PortfolioView`
/// dispatcher state-flips to `WidePortfolioView` scoped to that portfolio,
/// which avoids nesting NavigationStacks.
struct PortfoliosOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query(sort: \Portfolio.createdAt) private var portfolios: [Portfolio]
    @Query private var holdings: [Holding]
    @Query private var settingsList: [UserSettings]

    let onSelect: (PersistentIdentifier) -> Void

    @State private var portfolioToDelete: Portfolio?
    @State private var showingNewPortfolio = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                consolidatedHero
                portfolioList
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity)
        }
        .background(Color.tqBackground)
        .navigationTitle("Portfolios")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewPortfolio = true
                } label: {
                    Label("New Portfolio", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewPortfolio) {
            NewPortfolioSheet { name in
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let portfolio = Portfolio(name: trimmed)
                modelContext.insert(portfolio)
                try? modelContext.save()
            }
        }
        .alert(
            String(localized: "Delete portfolio?"),
            isPresented: Binding(
                get: { portfolioToDelete != nil },
                set: { if !$0 { portfolioToDelete = nil } }
            ),
            presenting: portfolioToDelete
        ) { portfolio in
            Button(role: .destructive) {
                deleteConfirmed(portfolio)
            } label: {
                Text("Delete")
            }
            Button(role: .cancel) {
                portfolioToDelete = nil
            } label: {
                Text("Cancel")
            }
        } message: { portfolio in
            if portfolio.holdings.isEmpty {
                Text("\"\(portfolio.name)\" will be removed.")
            } else {
                Text("\"\(portfolio.name)\" and its \(portfolio.holdings.count) holdings will be permanently removed. This cannot be undone.")
            }
        }
    }

    private func deleteConfirmed(_ portfolio: Portfolio) {
        modelContext.delete(portfolio)
        try? modelContext.save()
        portfolioToDelete = nil
    }

    // MARK: - Consolidated hero

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
                Button {
                    onSelect(portfolio.persistentModelID)
                } label: {
                    portfolioRow(portfolio)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        portfolioToDelete = portfolio
                    } label: {
                        Label("Delete portfolio", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func portfolioRow(_ portfolio: Portfolio) -> some View {
        let summary = summary(for: portfolio)
        let health = allocationHealth(for: summary)

        return TQCard {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
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
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(portfolio.holdings.count) holdings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: Theme.Spacing.sm)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: summary.totalValue.formatted())
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(summary.monthlyIncomeNet.formatted())/mo")
                        .font(.caption)
                        .foregroundStyle(Color.tqAccentGreen)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                allocationHealthPill(health)

                Menu {
                    Button(role: .destructive) {
                        portfolioToDelete = portfolio
                    } label: {
                        Label("Delete portfolio", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()

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

    /// One PortfolioSummary per portfolio, computed on the fly using the
    /// existing `computeSummary(holdings:)` helper. If this surface grows,
    /// promote to a real `PortfolioRepository.summariesPerPortfolio()` so
    /// repeated calls share a single pass.
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
}
