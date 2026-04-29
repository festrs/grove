import SwiftUI
import GroveDomain
import GroveServices
import GroveRepositories

struct InspectorPanel: View {
    let dividends: [DividendPayment]
    let suggestions: [RebalancingSuggestion]
    let allocations: [AssetClassAllocation]

    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates
    @State private var selectedTab = InspectorTab.agenda

    enum InspectorTab: String, CaseIterable {
        case agenda = "Schedule"
        case aportar = "Invest"
        case alertas = "Alerts"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with tab picker
            VStack(alignment: .leading, spacing: 10) {
                Text("PANEL")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                Picker("", selection: $selectedTab) {
                    ForEach(InspectorTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Tab content
            ScrollView {
                VStack(spacing: 12) {
                    switch selectedTab {
                    case .agenda:
                        agendaContent
                    case .aportar:
                        aportarContent
                    case .alertas:
                        alertasContent
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 280)
        .background(Color.tqBackground)
    }

    // MARK: - Agenda Tab

    @ViewBuilder
    private var agendaContent: some View {
        // Monthly total card
        TQCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("EXPECTED")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                let total = dividends.map { $0.totalAmountMoney }.sum(in: displayCurrency, using: rates)
                Text(total.formatted())
                    .font(.system(size: 26, weight: .bold))
                    .monospacedDigit()

                Text("\(dividends.count) payments")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            LinearGradient(
                colors: [Color.tqAccentGreen.opacity(0.08), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.card))
        )

        Text("UPCOMING PAYMENTS")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)

        ForEach(dividends.prefix(8), id: \.id) { dividend in
            dividendRow(dividend)
        }
    }

    private func dividendRow(_ dividend: DividendPayment) -> some View {
        HStack(spacing: 12) {
            // Date badge
            VStack(spacing: 1) {
                Text(dividend.paymentDate.shortMonthString)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text("\(Calendar.current.component(.day, from: dividend.paymentDate))")
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
            }
            .frame(width: 40, height: 40)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(dividend.holding?.displayTicker ?? "—")
                    .font(.system(size: 13, weight: .medium))
                Text("1 payment")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(dividend.totalAmountMoney.formatted(in: displayCurrency, using: rates))
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Aportar Tab

    @ViewBuilder
    private var aportarContent: some View {
        Text("LARGEST GAPS · ACTION THIS MONTH")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)

        ForEach(suggestions.prefix(6)) { suggestion in
            TQCard {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.tqAccentGreen.opacity(0.15))
                        .frame(width: 34, height: 34)
                        .overlay {
                            Text(String(suggestion.displayTicker.prefix(4)))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.tqAccentGreen)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.displayTicker)
                            .font(.system(size: 13, weight: .semibold))
                        Text(suggestion.displayName)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(suggestion.amount.formatted())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.tqAccentGreen)
                }
            }
        }
    }

    // MARK: - Alertas Tab

    @ViewBuilder
    private var alertasContent: some View {
        let alerts = alertsFromAllocations

        Text("\(alerts.count) ALERTS")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)

        ForEach(alerts, id: \.title) { alert in
            TQCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(alert.message)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(alert.isWarning ? Color.tqWarning : Color.tqAccentGreen)
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }
        }
    }

    private struct AlertItem {
        let title: String
        let message: String
        let isWarning: Bool
    }

    private var alertsFromAllocations: [AlertItem] {
        var alerts: [AlertItem] = []
        for alloc in allocations {
            let drift = NSDecimalNumber(decimal: alloc.drift).doubleValue
            if drift < -5 {
                alerts.append(AlertItem(
                    title: alloc.assetClass.displayName,
                    message: "Class \(String(format: "%.0f", abs(drift)))% below target — prioritize investment this month.",
                    isWarning: false
                ))
            } else if drift > 5 {
                alerts.append(AlertItem(
                    title: alloc.assetClass.displayName,
                    message: "Class \(String(format: "%.0f", drift))% above target — consider rebalancing.",
                    isWarning: true
                ))
            }
        }
        return alerts
    }
}

