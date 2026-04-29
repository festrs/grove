import SwiftUI
import Charts
import GroveDomain

struct PriceChartView: View {
    let ticker: String
    let currency: Currency
    let backendService: any BackendServiceProtocol

    @State private var points: [PriceChartPoint] = []
    @State private var isLoading = false
    @State private var selectedPeriod: ChartPeriod = .oneMonth

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var isRegular: Bool {
        #if os(macOS)
        return true
        #else
        return sizeClass == .regular
        #endif
    }

    var body: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                headerSection
                periodPicker
                chartContent
            }
        }
        .task { await loadData() }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Price History")
                    .font(.headline)
                if let last = points.last {
                    Text(last.price.formatted(as: currency))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            Spacer()
            if points.count >= 2 {
                let change = percentChange
                Text("\(change >= 0 ? "+" : "")\(String(format: "%.1f", change))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(change >= 0 ? Color.tqPositive : Color.tqNegative)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(
                        (change >= 0 ? Color.tqPositive : Color.tqNegative).opacity(0.15),
                        in: RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                    )
            }
        }
    }

    private var periodPicker: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(ChartPeriod.allCases) { period in
                Button(period.label) {
                    selectedPeriod = period
                    Task { await loadData() }
                }
                .font(.system(
                    size: isRegular ? 15 : 13,
                    weight: selectedPeriod == period ? .semibold : .regular
                ))
                .foregroundStyle(selectedPeriod == period ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, isRegular ? 8 : 5)
                .background(
                    selectedPeriod == period ? Color.tqAccentGreen : Color.clear,
                    in: Capsule()
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var chartContent: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 180)
        } else if points.isEmpty {
            Text("No data available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            priceChart
        }
    }

    private var priceChart: some View {
        let lineColor = percentChange >= 0 ? Color.tqPositive : Color.tqNegative
        let prices = points.map { NSDecimalNumber(decimal: $0.price).doubleValue }
        let minPrice = (prices.min() ?? 0) * 0.995
        let maxPrice = (prices.max() ?? 0) * 1.005

        return Chart(points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Price", NSDecimalNumber(decimal: point.price).doubleValue)
            )
            .foregroundStyle(lineColor)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", point.date),
                y: .value("Price", NSDecimalNumber(decimal: point.price).doubleValue)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [lineColor.opacity(0.2), lineColor.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: minPrice...maxPrice)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel(format: xAxisFormat)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 180)
    }

    // MARK: - Data

    private var xAxisFormat: Date.FormatStyle {
        switch selectedPeriod {
        case .oneDay, .oneWeek, .oneMonth:
            .dateTime.month(.abbreviated).day()
        case .threeMonths, .sixMonths:
            .dateTime.month(.abbreviated)
        case .oneYear, .fiveYears, .max:
            .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }

    private var percentChange: Double {
        guard let first = points.first, let last = points.last else { return 0 }
        let firstVal = NSDecimalNumber(decimal: first.price).doubleValue
        guard firstVal > 0 else { return 0 }
        let lastVal = NSDecimalNumber(decimal: last.price).doubleValue
        return ((lastVal - firstVal) / firstVal) * 100
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let dtos = try await backendService.fetchPriceHistory(
                symbol: ticker,
                period: selectedPeriod.apiValue
            )
            points = dtos.compactMap { dto -> PriceChartPoint? in
                guard let date = parseDate(dto.date) else { return nil }
                return PriceChartPoint(date: date, price: dto.price.decimalAmount)
            }
            .sorted { $0.date < $1.date }
        } catch {
            points = []
        }
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }
}

// MARK: - Supporting Types

private struct PriceChartPoint: Identifiable {
    let date: Date
    let price: Decimal

    var id: Date { date }
}

enum ChartPeriod: String, CaseIterable, Identifiable {
    case oneDay
    case oneWeek
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear
    case fiveYears
    case max

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneDay: "1D"
        case .oneWeek: "1W"
        case .oneMonth: "1M"
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        case .oneYear: "1Y"
        case .fiveYears: "5Y"
        case .max: "Max"
        }
    }

    var apiValue: String {
        switch self {
        case .oneDay: "1d"
        case .oneWeek: "5d"
        case .oneMonth: "1mo"
        case .threeMonths: "3mo"
        case .sixMonths: "6mo"
        case .oneYear: "1y"
        case .fiveYears: "5y"
        case .max: "max"
        }
    }
}
