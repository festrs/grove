import SwiftUI

struct ClassificationStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // MARK: - Header
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Classifique seus ativos")
                    .font(.system(size: Theme.FontSize.title2, weight: .bold))

                Text("Verificamos automaticamente a classe de cada ativo. Ajuste se necessario.")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Color.tqSecondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)

            // MARK: - Auto-classify Button
            Button {
                withAnimation { viewModel.autoClassifyAll() }
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "wand.and.stars")
                    Text("Auto-classificar")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.tqAccentGreen)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .trailing)

            // MARK: - Holdings List
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach($viewModel.pendingHoldings) { $holding in
                        classificationRow(holding: $holding)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }

            Spacer(minLength: 0)
        }
    }

    private func classificationRow(holding: Binding<PendingHolding>) -> some View {
        TQCard {
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: holding.wrappedValue.assetClass.icon)
                        .foregroundStyle(holding.wrappedValue.assetClass.color)
                        .font(.title3)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(holding.wrappedValue.ticker)
                            .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        Text(holding.wrappedValue.displayName)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundStyle(Color.tqSecondaryText)
                            .lineLimit(1)
                    }

                    Spacer()
                }

                Picker("Classe", selection: holding.assetClass) {
                    ForEach(AssetClassType.allCases) { assetClass in
                        Label(assetClass.displayName, systemImage: assetClass.icon)
                            .tag(assetClass)
                    }
                }
                .pickerStyle(.menu)
                .tint(holding.wrappedValue.assetClass.color)
            }
        }
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.pendingHoldings = [
        PendingHolding(ticker: "ITUB3", displayName: "Itau Unibanco", quantity: 556,
                       assetClass: .acoesBR, status: .aportar, currentPrice: 32.50, dividendYield: 6.5),
        PendingHolding(ticker: "XPML11", displayName: "XP Malls FII", quantity: 50,
                       assetClass: .fiis, status: .aportar, currentPrice: 98.00, dividendYield: 8.2),
        PendingHolding(ticker: "AAPL", displayName: "Apple Inc", quantity: 10,
                       assetClass: .usStocks, status: .aportar, currentPrice: 175.00, dividendYield: 0.5),
    ]
    return ClassificationStepView(viewModel: vm)
}
