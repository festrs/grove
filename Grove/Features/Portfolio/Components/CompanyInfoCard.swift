import SwiftUI
import GroveDomain

struct CompanyInfoCard: View {
    let holding: Holding

    var body: some View {
        if holding.hasCompanyInfo {
            TQCard {
                HStack(spacing: Theme.Spacing.md) {
                    logoView
                    infoColumns
                }
            }
        }
    }

    // MARK: - Logo

    private var logoView: some View {
        Group {
            if let urlString = holding.logoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        fallbackIcon
                    case .empty:
                        ProgressView()
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
    }

    private var fallbackIcon: some View {
        Image(systemName: holding.assetClass.icon)
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(width: 48, height: 48)
            .background(Color.tqBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
    }

    // MARK: - Info

    private var infoColumns: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let sector = holding.sector {
                HStack(spacing: 4) {
                    Image(systemName: "building.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(sector)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let marketCapString = holding.marketCap,
               let marketCap = Decimal(string: marketCapString) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Cap. \(formattedMarketCap(marketCap, currency: holding.currency))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Market Cap Formatting

    private func formattedMarketCap(_ value: Decimal, currency: Currency) -> String {
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        let symbol = currency.symbol

        if abs(doubleValue) >= 1_000_000_000_000 {
            return "\(symbol) \(String(format: "%.1fT", doubleValue / 1_000_000_000_000))"
        } else if abs(doubleValue) >= 1_000_000_000 {
            return "\(symbol) \(String(format: "%.1fB", doubleValue / 1_000_000_000))"
        } else if abs(doubleValue) >= 1_000_000 {
            return "\(symbol) \(String(format: "%.1fM", doubleValue / 1_000_000))"
        }
        return "\(symbol) \(String(format: "%.0f", doubleValue))"
    }
}
