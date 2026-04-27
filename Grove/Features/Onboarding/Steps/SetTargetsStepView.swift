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

            // MARK: - Total Indicator
            totalIndicator
                .padding(.horizontal, Theme.Spacing.lg)

            // MARK: - Sliders
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.assetClassesInUse) { assetClass in
                        allocationSlider(for: assetClass)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Distribution Bar

    private var distributionBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(viewModel.assetClassesInUse) { assetClass in
                    let pct = viewModel.targetAllocations[assetClass] ?? 0
                    let width = max(
                        4,
                        geo.size.width * CGFloat(truncating: pct as NSDecimalNumber) / 100
                    )
                    RoundedRectangle(cornerRadius: 3)
                        .fill(assetClass.color)
                        .frame(width: width)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.targetAllocations.values.map { $0 })
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
    }

    // MARK: - Total Indicator

    private var totalIndicator: some View {
        let total = viewModel.totalTargetAllocation
        let isValid = viewModel.isTargetValid
        let totalDouble = NSDecimalNumber(decimal: total).doubleValue

        return HStack {
            Text("Total:")
                .font(.system(size: Theme.FontSize.body, weight: .medium))

            Text("\(totalDouble, specifier: "%.0f")%")
                .font(.system(size: Theme.FontSize.body, weight: .bold))
                .foregroundStyle(isValid ? Color.tqAccentGreen : .red)

            Spacer()

            if !isValid {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(total > 100 ? "Above 100%" : "Below 100%")
                }
                .font(.system(size: Theme.FontSize.caption))
                .foregroundStyle(Color.tqWarning)
            } else {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Valid allocation")
                }
                .font(.system(size: Theme.FontSize.caption))
                .foregroundStyle(Color.tqAccentGreen)
            }
        }
    }

    // MARK: - Allocation Slider

    private func allocationSlider(for assetClass: AssetClassType) -> some View {
        let binding = Binding<Double>(
            get: {
                NSDecimalNumber(decimal: viewModel.targetAllocations[assetClass] ?? 0).doubleValue
            },
            set: {
                viewModel.targetAllocations[assetClass] = Decimal($0)
            }
        )

        let holdingCount = viewModel.pendingHoldings.filter { $0.assetClass == assetClass }.count
        let pctValue = NSDecimalNumber(decimal: viewModel.targetAllocations[assetClass] ?? 0).doubleValue

        return TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: assetClass.icon)
                        .foregroundStyle(assetClass.color)
                        .frame(width: 24)

                    Text(assetClass.displayName)
                        .font(.system(size: Theme.FontSize.body, weight: .medium))

                    Spacer()

                    Text("\(pctValue, specifier: "%.0f")%")
                        .font(.system(size: Theme.FontSize.body, weight: .bold))
                        .foregroundStyle(assetClass.color)
                        .frame(width: 50, alignment: .trailing)
                }

                Slider(value: binding, in: 0...100, step: 1)
                    .tint(assetClass.color)

                Text("\(holdingCount) asset\(holdingCount == 1 ? "" : "s")")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Color.tqSecondaryText)
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
        PendingHolding(ticker: "XPML11", displayName: "XP Malls FII", quantity: 0,
                       assetClass: .fiis, status: .estudo, currentPrice: 98.00, dividendYield: 8.2),
        PendingHolding(ticker: "AAPL", displayName: "Apple Inc", quantity: 0,
                       assetClass: .usStocks, status: .estudo, currentPrice: 175.00, dividendYield: 0.5),
    ]
    return SetTargetsStepView(viewModel: vm)
}
