import SwiftUI
import GroveDomain

struct SetTargetsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // MARK: - Header
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Allocation Target")
                    .font(.system(size: Theme.FontSize.title2, weight: .bold))

                Text("Define how much of your portfolio each class should represent.")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Color.tqSecondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)

            // MARK: - Distribution Bar
            distributionBar
                .padding(.horizontal, Theme.Spacing.lg)

            // MARK: - Editor (all 6 classes via shared component)
            ScrollView {
                TQCard {
                    VStack(spacing: Theme.Spacing.sm) {
                        TQAssetClassWeightsEditor(
                            weights: doubleWeightsBinding,
                            caption: { cls in
                                let count = viewModel.pendingHoldings.filter { $0.assetClass == cls }.count
                                if count == 0 { return String(localized: "No assets yet") }
                                return count == 1 ? "1 asset" : "\(count) assets"
                            }
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Decimal ↔ Double bridge for the shared editor

    private var doubleWeightsBinding: Binding<[AssetClassType: Double]> {
        Binding(
            get: {
                Dictionary(uniqueKeysWithValues: AssetClassType.allCases.map { cls in
                    (cls, NSDecimalNumber(decimal: viewModel.targetAllocations[cls] ?? 0).doubleValue)
                })
            },
            set: { newValue in
                for (cls, value) in newValue {
                    viewModel.targetAllocations[cls] = Decimal(value)
                }
            }
        )
    }

    // MARK: - Distribution Bar

    private var distributionBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(AssetClassType.allCases) { assetClass in
                    let pct = viewModel.targetAllocations[assetClass] ?? 0
                    let width = max(
                        0,
                        geo.size.width * CGFloat(truncating: pct as NSDecimalNumber) / 100
                    )
                    if width > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(assetClass.color)
                            .frame(width: width)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.targetAllocations.values.map { $0 })
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.pendingHoldings = [
        PendingHolding(ticker: "ITUB3", displayName: "Itau Unibanco", quantity: 0,
                       assetClass: .acoesBR, status: .estudo, currentPrice: 32.50, dividendYield: 6.5),
        PendingHolding(ticker: "PETR4", displayName: "Petrobras PN", quantity: 0,
                       assetClass: .acoesBR, status: .estudo, currentPrice: 36.80, dividendYield: 12.3),
        PendingHolding(ticker: "XPML11", displayName: "XP Malls FII", quantity: 0,
                       assetClass: .fiis, status: .estudo, currentPrice: 98.00, dividendYield: 8.2),
        PendingHolding(ticker: "AAPL", displayName: "Apple Inc", quantity: 0,
                       assetClass: .usStocks, status: .estudo, currentPrice: 175.00, dividendYield: 0.5),
    ]
    return SetTargetsStepView(viewModel: vm)
        .preferredColorScheme(.dark)
}
