#if DEBUG
import SwiftUI
import SwiftData
import UserNotifications
import GroveDomain

struct DebugFloatingButton: View {
    @State private var showingSheet = false
    @State private var position = CGPoint(x: 60, y: 300)
    @GestureState private var dragOffset = CGSize.zero

    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 44, height: 44)
            .overlay {
                Image(systemName: "ladybug.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.red)
            }
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .position(
                x: position.x + dragOffset.width,
                y: position.y + dragOffset.height
            )
            .onTapGesture { showingSheet = true }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        position.x += value.translation.width
                        position.y += value.translation.height
                    }
            )
            .sheet(isPresented: $showingSheet) {
                DebugMenuView()
            }
    }
}

// MARK: - Debug Menu

struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var pendingCount = 0
    @State private var pendingDetails: [String] = []
    @AppStorage(AppConstants.Debug.unlimitedHoldingsKey) private var unlimitedHoldings = false

    var body: some View {
        NavigationStack {
            List {
                limitsSection
                notificationsSection
                dataSection
                infoSection
            }
            .navigationTitle("Debug Menu")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        #if os(macOS)
        // SwiftUI sheets on macOS render at a tiny default size; without an
        // explicit frame the List rows get clipped to nothing.
        .frame(minWidth: 480, idealWidth: 540, minHeight: 580, idealHeight: 640)
        #endif
    }

    // MARK: - Limits

    private var limitsSection: some View {
        Section {
            Toggle("Unlimited Holdings", isOn: $unlimitedHoldings)
        } header: {
            Text("Free-tier limits")
        } footer: {
            Text("Bypasses the \(AppConstants.freeTierMaxHoldings)-asset cap. DEBUG builds only.")
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            Button("Test Monthly Reminder") {
                Task { await NotificationService.shared.scheduleMonthlyRebalancingReminder() }
            }
            Button("Test Dividend (ITUB3)") {
                Task {
                    await NotificationService.shared.scheduleDividendNotification(
                        ticker: "ITUB3", amount: Money(amount: 42.50, currency: .brl), date: .now
                    )
                }
            }
            Button("Test Milestone (50%)") {
                Task { await NotificationService.shared.scheduleMilestoneNotification(percent: 50) }
            }
            Button("Test Drift Alert") {
                Task {
                    await NotificationService.shared.scheduleDriftNotification(
                        assetClass: "Brazilian Stocks", driftPercent: 8.3
                    )
                }
            }

            Button("Check Pending") {
                Task {
                    let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
                    pendingCount = pending.count
                    pendingDetails = pending.map { "[\($0.identifier)] \($0.content.title)" }
                }
            }

            if pendingCount > 0 {
                ForEach(pendingDetails, id: \.self) { detail in
                    Text(detail)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Button("Clear All Pending", role: .destructive) {
                Task {
                    await NotificationService.shared.removeAllPending()
                    pendingCount = 0
                    pendingDetails = []
                }
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("Data") {
            Button("Load Sample Data") {
                loadSampleData()
            }

            Button("Reset Milestone Tracker") {
                UserDefaults.standard.set(0, forKey: "notif_lastMilestone")
            }

            Button("Reset Drift Throttle") {
                UserDefaults.standard.removeObject(forKey: "notif_lastDriftDate")
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section("Info") {
            let milestone = UserDefaults.standard.integer(forKey: "notif_lastMilestone")
            LabeledContent("Last Milestone", value: "\(milestone)%")

            if let driftDate = UserDefaults.standard.object(forKey: "notif_lastDriftDate") as? Date {
                LabeledContent("Last Drift Alert", value: driftDate.formatted(.dateTime.month().day().hour().minute()))
            } else {
                LabeledContent("Last Drift Alert", value: "Never")
            }
        }
    }

    // MARK: - Sample Data

    private func loadSampleData() {
        let descriptor = FetchDescriptor<Portfolio>(sortBy: [SortDescriptor(\.createdAt)])
        let portfolio: Portfolio
        if let existing = try? modelContext.fetch(descriptor).first {
            portfolio = existing
        } else {
            portfolio = Portfolio(name: "My Portfolio")
            modelContext.insert(portfolio)
        }

        if let settings = (try? modelContext.fetch(FetchDescriptor<UserSettings>()))?.first {
            settings.classAllocations = [
                .acoesBR: 27, .fiis: 15, .usStocks: 28,
                .reits: 10, .crypto: 5, .rendaFixa: 5,
            ]
        }

        let existingTickers = Set(portfolio.holdings.map(\.ticker))
        for (i, holding) in Holding.allSamples.enumerated() {
            guard !existingTickers.contains(holding.ticker) else { continue }
            modelContext.insert(holding)
            holding.portfolio = portfolio
            seedTransactions(for: holding, seedIndex: i)
            holding.recalculateFromContributions()
        }

        let settingsDesc = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(settingsDesc).first {
            settings.hasCompletedOnboarding = true
            settings.monthlyIncomeGoal = 10_000
        } else {
            let settings = UserSettings(
                monthlyIncomeGoal: 10_000,
                monthlyCostOfLiving: 15_000,
                hasCompletedOnboarding: true
            )
            modelContext.insert(settings)
        }

        try? modelContext.save()
    }

    /// Generate a realistic transaction history for a sample holding so the
    /// detail screen, dashboard charts, and rebalancing flow have data to
    /// chew on. Builds 3 buys spread across the last year at prices that
    /// drift around the average, plus a partial sell for `.vender` status.
    private func seedTransactions(for holding: Holding, seedIndex: Int) {
        guard holding.quantity > 0 else { return }
        let calendar = Calendar.current
        let totalShares = holding.quantity
        let avg = holding.averagePrice
        let priceJitter: [Decimal] = [0.92, 1.0, 1.08]
        let monthOffsets = [-12, -8 - seedIndex % 3, -3 - seedIndex % 2]
        let shareSplits: [Decimal] = [0.4, 0.35, 0.25]

        for idx in 0..<3 {
            let shares = (totalShares * shareSplits[idx]).rounded(decimals: 4)
            let price = (avg * priceJitter[idx]).rounded(decimals: 2)
            let date = calendar.date(byAdding: .month, value: monthOffsets[idx], to: .now) ?? .now
            let buy = Contribution(
                date: date,
                amount: shares * price,
                shares: shares,
                pricePerShare: price
            )
            modelContext.insert(buy)
            buy.holding = holding
        }

        if holding.status == .vender {
            let sellShares = (totalShares * 0.2).rounded(decimals: 4)
            let sellPrice = (avg * 0.95).rounded(decimals: 2)
            let sellDate = calendar.date(byAdding: .month, value: -1, to: .now) ?? .now
            let sell = Contribution(
                date: sellDate,
                amount: -(sellShares * sellPrice),
                shares: -sellShares,
                pricePerShare: sellPrice
            )
            modelContext.insert(sell)
            sell.holding = holding
        }
    }
}

private extension Decimal {
    func rounded(decimals: Int) -> Decimal {
        var input = self
        var output = Decimal()
        NSDecimalRound(&output, &input, decimals, .plain)
        return output
    }
}
#endif
