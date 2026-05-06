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
    @Query private var dividends: [DividendPayment]
    @State private var viewModel = DividendCalendarViewModel()

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
            viewModel.loadFromLocal(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
        }
        .task {
            viewModel.loadFromLocal(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
        }
        .onChange(of: dividends.count) {
            viewModel.loadFromLocal(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
        }
        .onChange(of: syncService.isSyncing) { _, syncing in
            if !syncing {
                viewModel.loadFromLocal(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
            }
        }
    }

    private var compactCalendarLayout: some View {
        VStack(spacing: Theme.Spacing.md) {
            monthHeader
            monthlyTotalCard

            CalendarMonthGrid(
                month: viewModel.selectedMonth,
                daysWithDividends: viewModel.daysWithDividends,
                selectedDay: viewModel.selectedDay?.dayOfMonth,
                onDaySelected: { day in viewModel.selectDay(day) }
            )
            .padding(.horizontal, Theme.Spacing.md)

            if !viewModel.dividendsForDay.isEmpty {
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
                    month: viewModel.selectedMonth,
                    daysWithDividends: viewModel.daysWithDividends,
                    selectedDay: viewModel.selectedDay?.dayOfMonth,
                    onDaySelected: { day in viewModel.selectDay(day) }
                )
            }
            .frame(minWidth: 350, maxWidth: 450)

            // Right: monthly total + day detail
            VStack(spacing: Theme.Spacing.md) {
                monthlyTotalCard

                if !viewModel.dividendsForDay.isEmpty {
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
                viewModel.previousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            Spacer()
            Text(viewModel.selectedMonth.monthYearString)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
            Button {
                viewModel.nextMonth()
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
                    Text(viewModel.monthlyTotal.formatted())
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
                let total = viewModel.dividendsForDay.map { $0.amount }.sum(in: displayCurrency, using: rates)
                HStack {
                    Text("Daily Dividends")
                        .font(.headline)
                    Spacer()
                    Text(total.formatted())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.tqAccentGreen)
                }

                ForEach(viewModel.dividendsForDay) { div in
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
}

#Preview {
    DividendCalendarView()
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self], inMemory: true)
}
