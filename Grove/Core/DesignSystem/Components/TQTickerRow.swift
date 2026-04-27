import SwiftUI
import GroveDomain

/// Unified ticker row used across the app for consistent holding/asset display.
///
/// Supports multiple configurations:
/// - **Standard**: Icon circle + ticker + subtitle + right detail (portfolio list)
/// - **Compact**: Optional checkbox + ticker + class badge + right detail (import, search)
/// - **Minimal**: Ticker + subtitle + right detail (suggestions, dividends)
struct TQTickerRow: View {
    let ticker: String
    var subtitle: String? = nil
    var assetClass: AssetClassType? = nil

    // Left accessory
    var showIcon: Bool = false
    var showCheckbox: Bool = false
    var isSelected: Bool = false
    var isDisabled: Bool = false

    // Class badge
    var showClassBadge: Bool = false

    // Right detail
    var trailingTitle: String? = nil
    var trailingSubtitle: String? = nil
    var trailingStyle: TrailingStyle = .standard

    enum TrailingStyle {
        case standard
        case positive
        case negative
        case accent
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Left accessory
            if showCheckbox {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.tqAccentGreen : Color.tqSecondaryText.opacity(0.4))
            } else if showIcon, let assetClass {
                Circle()
                    .fill(assetClass.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: assetClass.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(assetClass.color)
                    }
            }

            // Ticker + subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(ticker)
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        .foregroundStyle(isDisabled ? .tertiary : .primary)

                    if showClassBadge, let assetClass {
                        Text(assetClass.shortName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(assetClass.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(assetClass.color.opacity(0.15), in: Capsule())
                    }
                }

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundStyle(Color.tqSecondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right detail
            if trailingTitle != nil || trailingSubtitle != nil {
                VStack(alignment: .trailing, spacing: 2) {
                    if let title = trailingTitle {
                        Text(title)
                            .font(.system(size: Theme.FontSize.body, weight: .medium))
                            .foregroundStyle(trailingColor)
                    }
                    if let sub = trailingSubtitle {
                        Text(sub)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundStyle(Color.tqSecondaryText)
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .opacity(isDisabled ? 0.4 : 1)
    }

    private var trailingColor: Color {
        switch trailingStyle {
        case .standard: .primary
        case .positive: .tqPositive
        case .negative: .tqNegative
        case .accent: .tqAccentGreen
        }
    }
}

// MARK: - Previews

#Preview("Standard with icon") {
    VStack(spacing: 0) {
        TQTickerRow(
            ticker: "ITUB3",
            subtitle: "1.911 cotas",
            assetClass: .acoesBR,
            showIcon: true,
            trailingTitle: "R$ 32,00",
            trailingSubtitle: "+12,5%"
        )
        Divider()
        TQTickerRow(
            ticker: "BTLG11",
            subtitle: "50 cotas",
            assetClass: .fiis,
            showIcon: true,
            trailingTitle: "R$ 100,00",
            trailingSubtitle: "-3,2%",
            trailingStyle: .negative
        )
    }
    .padding()
    .background(Color.tqBackground)
    .preferredColorScheme(.dark)
}

#Preview("Compact with checkbox") {
    VStack(spacing: 0) {
        TQTickerRow(
            ticker: "AGRO3",
            subtitle: "BRASILAGRO S.A.",
            assetClass: .acoesBR,
            showCheckbox: true,
            isSelected: true,
            showClassBadge: true,
            trailingTitle: "400 cotas",
            trailingSubtitle: "R$ 7.904,00"
        )
        Divider()
        TQTickerRow(
            ticker: "BTLG11",
            subtitle: "BTG LOGISTICA",
            assetClass: .fiis,
            showCheckbox: true,
            isSelected: false,
            showClassBadge: true,
            trailingTitle: "50 cotas",
            trailingSubtitle: "R$ 5.000,00"
        )
        Divider()
        TQTickerRow(
            ticker: "WEGE3",
            subtitle: "WEG S.A.",
            assetClass: .acoesBR,
            showCheckbox: true,
            isSelected: false,
            isDisabled: true,
            showClassBadge: true
        )
    }
    .padding()
    .background(Color.tqBackground)
    .preferredColorScheme(.dark)
}

#Preview("Minimal") {
    VStack(spacing: 0) {
        TQTickerRow(
            ticker: "ITUB3",
            subtitle: "25 Abr",
            trailingTitle: "R$ 156,00",
            trailingStyle: .accent
        )
        Divider()
        TQTickerRow(
            ticker: "AAPL",
            subtitle: "30 Abr",
            trailingTitle: "R$ 42,50",
            trailingStyle: .accent
        )
    }
    .padding()
    .background(Color.tqBackground)
    .preferredColorScheme(.dark)
}
