import SwiftUI
import GroveDomain

struct SetStatusStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Asset Status")
                        .font(.system(size: Theme.FontSize.title2, weight: .bold))

                    Text("Define the strategy for each asset in your portfolio.")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundStyle(Color.tqSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // MARK: - Legend
                statusLegend

                // MARK: - Grouped List
                ForEach(viewModel.assetClassesInUse) { assetClass in
                    assetClassGroup(assetClass)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }

    // MARK: - Status Legend

    private var statusLegend: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(HoldingStatus.allCases) { status in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: status.icon)
                            .foregroundStyle(status.color)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(status.displayName)
                                .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                            Text(status.description)
                                .font(.system(size: Theme.FontSize.caption))
                                .foregroundStyle(Color.tqSecondaryText)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Asset Class Group

    private func assetClassGroup(_ assetClass: AssetClassType) -> some View {
        let holdings = viewModel.pendingHoldings.filter { $0.assetClass == assetClass }

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Group Header
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: assetClass.icon)
                    .foregroundStyle(assetClass.color)
                Text(assetClass.displayName)
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                Text("(\(holdings.count))")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Color.tqSecondaryText)
            }

            ForEach(holdings) { holding in
                if let index = viewModel.pendingHoldings.firstIndex(where: { $0.id == holding.id }) {
                    statusRow(index: index)
                }
            }
        }
    }

    private func statusRow(index: Int) -> some View {
        let holding = viewModel.pendingHoldings[index]

        return TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(holding.ticker)
                            .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        Text(holding.displayName)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundStyle(Color.tqSecondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(holding.displayName)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundStyle(Color.tqSecondaryText)
                        .lineLimit(1)
                }

                Picker("Status", selection: $viewModel.pendingHoldings[index].status) {
                    Text("Study").tag(HoldingStatus.estudo)
                    Text("Invest").tag(HoldingStatus.aportar)
                    Text("Quarant.").tag(HoldingStatus.quarentena)
                    Text("Sell").tag(HoldingStatus.vender)
                }
                .pickerStyle(.segmented)

                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: holding.status.icon)
                        .foregroundStyle(holding.status.color)
                        .font(.caption2)
                    Text(holding.status.description)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundStyle(Color.tqSecondaryText)
                }
            }
        }
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.pendingHoldings = [
        PendingHolding(ticker: "ITUB3", displayName: "Itau Unibanco", quantity: 0,
                       assetClass: .acoesBR, status: .estudo, currentPrice: 32.50, dividendYield: 6.5),
        PendingHolding(ticker: "PETR4", displayName: "Petrobras PN", quantity: 0,
                       assetClass: .acoesBR, status: .estudo, currentPrice: 36.80, dividendYield: 12.3),
        PendingHolding(ticker: "VALE3", displayName: "Vale ON", quantity: 0,
                       assetClass: .acoesBR, status: .estudo, currentPrice: 58.00, dividendYield: 8.0),
        PendingHolding(ticker: "XPML11", displayName: "XP Malls FII", quantity: 0,
                       assetClass: .fiis, status: .estudo, currentPrice: 98.00, dividendYield: 8.2),
        PendingHolding(ticker: "AAPL", displayName: "Apple Inc", quantity: 0,
                       assetClass: .usStocks, status: .estudo, currentPrice: 175.00, dividendYield: 0.5),
    ]
    return SetStatusStepView(viewModel: vm)
}
