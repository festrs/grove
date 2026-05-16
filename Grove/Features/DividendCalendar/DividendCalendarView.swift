import SwiftUI
import SwiftData
import GroveDomain

struct DividendCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @Query(sort: \DividendPayment.paymentDate, order: .reverse) private var payments: [DividendPayment]

    @State private var selectedMonth: Date = .now
    @State private var selectedDay: Date?

    private var allDividends: [CalendarDividend] {
        payments.compactMap(CalendarDividend.init(from:))
    }

    private var dividendsForMonth: [CalendarDividend] {
        allDividends.inMonth(selectedMonth)
    }

    private var dividendsForDay: [CalendarDividend] {
        guard let selectedDay else { return [] }
        return dividendsForMonth.onDay(Calendar.current.component(.day, from: selectedDay))
    }

    private var monthlyTotal: Money {
        dividendsForMonth.map(\.amount).sum(in: displayCurrency, using: rates)
    }

    private var daysWithDividends: Set<Int> {
        dividendsForMonth.daysWithDividends()
    }

    var body: some View {
        ScrollView {
            if sizeClass == .regular {
                wideCalendarLayout
            } else {
                compactCalendarLayout
            }
        }
        .navigationTitle("Dividends")
        .refreshable {
            await syncService.syncAll(modelContext: modelContext, backendService: backendService)
            // Explicit user tap on a dividend screen — bypass the once-per-day
            // gate so newly-published payments land immediately.
            try? await syncService.syncDividends(modelContext: modelContext, backendService: backendService)
            try? modelContext.save()
        }
        .onChange(of: selectedMonth) { selectedDay = nil }
    }

    private var compactCalendarLayout: some View {
        VStack(spacing: Theme.Spacing.md) {
            monthHeader
            monthlyTotalCard

            CalendarMonthGrid(
                month: selectedMonth,
                daysWithDividends: daysWithDividends,
                selectedDay: selectedDay?.dayOfMonth,
                onDaySelected: selectDay
            )
            .padding(.horizontal, Theme.Spacing.md)

            if !dividendsForDay.isEmpty {
                dayDetailCard
                    .padding(.horizontal, Theme.Spacing.md)
            }
        }
        .padding(.vertical, Theme.Spacing.md)
    }

    private var wideCalendarLayout: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // Left: month nav + calendar grid
            VStack(spacing: Theme.Spacing.md) {
                monthHeader

                CalendarMonthGrid(
                    month: selectedMonth,
                    daysWithDividends: daysWithDividends,
                    selectedDay: selectedDay?.dayOfMonth,
                    onDaySelected: selectDay
                )
            }
            .frame(minWidth: 350, maxWidth: 450)

            // Right: monthly total + day detail
            VStack(spacing: Theme.Spacing.md) {
                monthlyTotalCard

                if !dividendsForDay.isEmpty {
                    dayDetailCard
                }

                Spacer()
            }
            .frame(minWidth: 280)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: Theme.Layout.maxContentWidth)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            Spacer()
            Text(selectedMonth.monthYearString)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var monthlyTotalCard: some View {
        TQCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(monthlyTotal.formatted())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.tqAccentGreen)
                }
                Spacer()
                Image(systemName: "banknote")
                    .font(.title)
                    .foregroundStyle(Color.tqAccentGreen.opacity(0.5))
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var dayDetailCard: some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                let total = dividendsForDay.map(\.amount).sum(in: displayCurrency, using: rates)
                HStack {
                    Text("Daily Dividends")
                        .font(.headline)
                    Spacer()
                    Text(total.formatted())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.tqAccentGreen)
                }

                ForEach(dividendsForDay) { div in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(div.symbol)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(div.type)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(div.amount.formatted())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.tqAccentGreen)
                    }
                }
            }
        }
    }

    private func selectDay(_ day: Int) {
        var components = Calendar.current.dateComponents([.year, .month], from: selectedMonth)
        components.day = day
        selectedDay = Calendar.current.date(from: components)
    }

    private func shiftMonth(by months: Int) {
        if let shifted = Calendar.current.date(byAdding: .month, value: months, to: selectedMonth) {
            selectedMonth = shifted
        }
    }
}

#Preview {
    DividendCalendarView()
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, GroveDomain.Transaction.self, UserSettings.self], inMemory: true)
}
