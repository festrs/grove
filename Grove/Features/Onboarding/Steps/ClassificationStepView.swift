import SwiftUI

struct ClassificationStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Classify Your Assets")
                        .font(.system(size: Theme.FontSize.title2, weight: .bold))

                    Text("We automatically verified each asset's class. Adjust if necessary.")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundStyle(Color.tqSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // MARK: - Auto-classify Button
                Button {
                    withAnimation { viewModel.autoClassifyAll() }
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "wand.and.stars")
                        Text("Auto-classify")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.tqAccentGreen)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                // MARK: - Holdings List
                ForEach($viewModel.pendingHoldings) { $holding in
                    classificationRow(holding: $holding)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }

    private func classificationRow(holding: Binding<PendingHolding>) -> some View {
        TQCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.wrappedValue.ticker)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    Text(holding.wrappedValue.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TQAssetClassPicker(selection: holding.assetClass)
            }
        }
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.pendingHoldings = [
        PendingHolding(ticker: "ITUB3.SA", displayName: "Itau Unibanco Holding S.A.", quantity: 0,
                       assetClass: .acoesBR, status: .estudo, currentPrice: 32.50, dividendYield: 6.5),
        PendingHolding(ticker: "O", displayName: "Realty Income Corp", quantity: 0,
                       assetClass: .reits, status: .estudo, currentPrice: 55.00, dividendYield: 5.8),
        PendingHolding(ticker: "NVDA", displayName: "NVIDIA Corp", quantity: 0,
                       assetClass: .usStocks, status: .estudo, currentPrice: 880.00, dividendYield: 0.02),
        PendingHolding(ticker: "KNRI11.SA", displayName: "Kinea Renda Imobiliaria", quantity: 0,
                       assetClass: .fiis, status: .estudo, currentPrice: 167.00, dividendYield: 7.5),
        PendingHolding(ticker: "AAPL", displayName: "Apple Inc", quantity: 0,
                       assetClass: .usStocks, status: .estudo, currentPrice: 175.00, dividendYield: 0.5),
    ]
    return ClassificationStepView(viewModel: vm)
        .preferredColorScheme(.dark)
}
