import SwiftUI
import SwiftData

struct DividendCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.syncService) private var syncService
    @Environment(\.horizontalSizeClass) private var sizeClass
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
            viewModel.loadFromLocal(modelContext: modelContext)
        }
        .task {
            viewModel.loadFromLocal(modelContext: modelContext)
        }
        .onChange(of: dividends.count) {
            viewModel.loadFromLocal(modelContext: modelContext)
        }
        .onChange(of: syncService.isSyncing) { _, syncing in
            if !syncing {
                viewModel.loadFromLocal(modelContext: modelContext)
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
                    Text(viewModel.monthlyTotal.formattedBRL())
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
                let total = viewModel.dividendsForDay.reduce(Decimal.zero) { $0 + $1.amount }
                HStack {
                    Text("Daily Dividends")
                        .font(.headline)
                    Spacer()
                    Text(total.formattedBRL())
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
                        Text(div.amount.formattedBRL())
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
