import SwiftUI

struct CalendarMonthGrid: View {
    let month: Date
    let daysWithDividends: Set<Int>
    let selectedDay: Int?
    let onDaySelected: (Int) -> Void

    private let weekDays = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sab"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: month)?.count ?? 30
    }

    private var firstWeekday: Int {
        let components = Calendar.current.dateComponents([.year, .month], from: month)
        guard let firstDay = Calendar.current.date(from: components) else { return 0 }
        return Calendar.current.component(.weekday, from: firstDay) - 1
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.xs) {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: columns, spacing: Theme.Spacing.xs) {
                // Empty cells for days before month starts
                ForEach(0..<firstWeekday, id: \.self) { index in
                    Color.clear.frame(height: 40)
                        .id("empty-\(index)")
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    DividendDayCell(
                        day: day,
                        hasDividend: daysWithDividends.contains(day),
                        isSelected: selectedDay == day
                    )
                    .onTapGesture {
                        onDaySelected(day)
                    }
                }
            }
        }
    }
}
