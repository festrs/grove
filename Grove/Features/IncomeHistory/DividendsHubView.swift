import SwiftUI

/// Top-level "Dividends" destination — combines the upcoming-dividends
/// calendar and the historical/projected income aggregation behind a single
/// segmented control. Users land on Calendar by default ("when's my next
/// dividend?") and switch to Income for the windowed totals + per-class
/// breakdown.
struct DividendsHubView: View {
    @State private var segment: Segment = .calendar

    enum Segment: String, CaseIterable, Identifiable {
        case calendar
        case income
        var id: String { rawValue }
        var label: String {
            switch self {
            case .calendar: "Calendar"
            case .income: "Income"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $segment) {
                ForEach(Segment.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(Theme.Spacing.md)

            // Each segment owns its own navigationTitle, so the title
            // flips contextually as the user switches.
            switch segment {
            case .calendar:
                DividendCalendarView()
            case .income:
                IncomeHistoryView()
            }
        }
    }
}
