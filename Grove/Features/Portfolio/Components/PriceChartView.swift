import SwiftUI
import Charts

struct PriceChartView: View {
    let ticker: String
    let currency: Currency

    @Environment(\.backendService) private var backendService
    @State private var points: [PriceChartPoint] = []
    @State private var isLoading = false
    @State private var selectedPeriod: ChartPeriod = .oneMonth

    var body: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                headerSection
                periodPicker
                chartContent
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Historico de precos")
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
        Picker("Periodo", selection: $selectedPeriod) {
            ForEach(ChartPeriod.allCases) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedPeriod) {
            Task { await loadData() }
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 180)
        } else if points.isEmpty {
            Text("Sem dados disponiveis")
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
                x: .value("Data", point.date),
                y: .value("Preco", NSDecimalNumber(decimal: point.price).doubleValue)
            )
            .foregroundStyle(lineColor)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Data", point.date),
                y: .value("Preco", NSDecimalNumber(decimal: point.price).doubleValue)
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
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
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
    case oneMonth
    case threeMonths
    case oneYear

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneMonth: "1M"
        case .threeMonths: "3M"
        case .oneYear: "1A"
        }
    }

    var apiValue: String {
        switch self {
        case .oneMonth: "1mo"
        case .threeMonths: "3mo"
        case .oneYear: "1y"
        }
    }
}

// MARK: - Task Modifier

extension PriceChartView {
    func onAppearLoad() -> some View {
        self.task { await loadData() }
    }
}
