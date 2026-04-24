import SwiftUI

struct FundamentalsCard: View {
    let fundamentals: FundamentalsDTO?
    let isLoading: Bool

    var body: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Fundamentos")
                        .font(.headline)
                    Spacer()
                    if let score = fundamentals?.compositeScore {
                        compositeScoreBadge(score)
                    }
                }

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else if let fundamentals {
                    metricsGrid(fundamentals)

                    if let updatedAt = fundamentals.updatedAt {
                        Text("Atualizado: \(formatDate(updatedAt))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("Dados fundamentalistas indisponiveis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
        }
    }

    // MARK: - Composite Score Badge

    private func compositeScoreBadge(_ score: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text(String(format: "%.1f", score))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .foregroundStyle(ratingColor(for: score, thresholds: (6.0, 4.0)))
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            ratingColor(for: score, thresholds: (6.0, 4.0)).opacity(0.15),
            in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
        )
    }

    // MARK: - Metrics Grid

    private func metricsGrid(_ data: FundamentalsDTO) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: Theme.Spacing.sm
        ) {
            if let profitable = data.profitableYearsPct {
                metricItem(
                    label: "Lucros consistentes",
                    value: String(format: "%.0f%%", profitable),
                    rating: data.profitRating,
                    color: ratingColor(for: profitable, thresholds: (80, 50))
                )
            }

            if let epsGrowth = data.epsGrowthPct {
                metricItem(
                    label: "Crescimento LPA",
                    value: String(format: "%+.1f%%", epsGrowth),
                    rating: data.epsRating,
                    color: ratingColor(for: epsGrowth, thresholds: (5, 0))
                )
            }

            if let netDebt = data.currentNetDebtEbitda {
                metricItem(
                    label: "Div. liq./EBITDA",
                    value: String(format: "%.1fx", netDebt),
                    rating: data.debtRating,
                    color: debtColor(netDebt)
                )
            }

            if let ipoYears = data.ipoYears {
                metricItem(
                    label: "Anos de bolsa",
                    value: "\(ipoYears) anos",
                    rating: data.ipoRating,
                    color: ratingColor(for: Double(ipoYears), thresholds: (10, 5))
                )
            }
        }
    }

    // MARK: - Metric Item

    private func metricItem(label: String, value: String, rating: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                if let rating {
                    Text(rating)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(letterRatingColor(rating))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            letterRatingColor(rating).opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(Color.tqBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
    }

    // MARK: - Color Helpers

    private func ratingColor(for value: Double, thresholds: (good: Double, warning: Double)) -> Color {
        if value >= thresholds.good { return .tqPositive }
        if value >= thresholds.warning { return .tqWarning }
        return .tqNegative
    }

    private func debtColor(_ value: Double) -> Color {
        // Lower debt is better
        if value <= 2.0 { return .tqPositive }
        if value <= 3.5 { return .tqWarning }
        return .tqNegative
    }

    private func letterRatingColor(_ rating: String) -> Color {
        switch rating.uppercased() {
        case "A": return .tqPositive
        case "B": return .tqWarning
        default: return .tqNegative
        }
    }

    // MARK: - Date Formatting

    private func formatDate(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        guard let date = isoFormatter.date(from: isoString) else { return isoString }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: date)
    }
}
