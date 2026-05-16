import Testing
import Foundation
import SwiftData
import GroveDomain
import GroveServices
@testable import Grove

@Suite(.serialized)
struct IncomeTrendsViewModelTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    @MainActor
    private static func seed12MonthlyDividends(_ ctx: ModelContext, holdings: [Holding], amountPerShare: Decimal = 1) {
        let cal = Calendar.current
        let firstBuy = cal.date(byAdding: .month, value: -24, to: .now) ?? .now
        for h in holdings where h.status != .estudo {
            let c = Transaction(date: firstBuy, amount: 1, shares: h.quantity, pricePerShare: h.averagePrice)
            ctx.insert(c); c.holding = h
            for offset in 1...12 {
                let monthBack = cal.date(byAdding: .month, value: -offset, to: .now) ?? .now
                let payDate = cal.date(byAdding: .day, value: 1, to: monthBack) ?? monthBack
                let exDate = cal.date(byAdding: .day, value: -2, to: payDate) ?? monthBack
                let p = DividendPayment(exDate: exDate, paymentDate: payDate, amountPerShare: amountPerShare)
                ctx.insert(p); p.holding = h
            }
        }
        try? ctx.save()
    }

    // MARK: - Initial state

    @MainActor
    @Test func initialStateIsEmpty() {
        let vm = IncomeTrendsViewModel()
        #expect(vm.monthlyHistory.isEmpty)
        #expect(vm.yoyGrowth == nil)
        #expect(vm.topPayers.isEmpty)
        #expect(vm.concentration == nil)
        #expect(vm.currentMonth == nil)
        #expect(vm.monthlyGoal == nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - loadData populates all four sections

    @MainActor
    @Test func loadDataPopulatesMonthlyHistory() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)
        Self.seed12MonthlyDividends(ctx, holdings: holdings)

        let vm = IncomeTrendsViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        // 12 past months + 3 lookahead = 15 buckets
        #expect(vm.monthlyHistory.count == 15)
        #expect(vm.monthlyHistory.contains { $0.paid.amount > 0 })
    }

    @MainActor
    @Test func loadDataPopulatesYoyGrowth() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)
        Self.seed12MonthlyDividends(ctx, holdings: holdings)

        let vm = IncomeTrendsViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        // Only current 12mo seeded → priorTTM is zero, percent is nil.
        #expect(vm.yoyGrowth != nil)
        #expect(vm.yoyGrowth?.percent == nil)
        #expect(vm.yoyGrowth?.currentTTM.amount ?? 0 > 0)
    }

    @MainActor
    @Test func loadDataPopulatesTopPayers() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)
        Self.seed12MonthlyDividends(ctx, holdings: holdings)

        let vm = IncomeTrendsViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        // Three non-study holdings have records → 3 top payers.
        #expect(vm.topPayers.count == 3)
        // Sorted descending by TTM.
        for i in 0..<vm.topPayers.count - 1 {
            let lhs = vm.topPayers[i].ttm.converted(to: .brl, using: Self.rates).amount
            let rhs = vm.topPayers[i + 1].ttm.converted(to: .brl, using: Self.rates).amount
            #expect(lhs >= rhs)
        }
    }

    @MainActor
    @Test func loadDataPopulatesConcentration() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)
        Self.seed12MonthlyDividends(ctx, holdings: holdings)

        let vm = IncomeTrendsViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.concentration != nil)
        // Three earning holdings, default topN of 5 → no Rest segment.
        #expect(vm.concentration?.segments.count == 3)
        #expect(vm.concentration?.topShare == 100)
    }

    @MainActor
    @Test func loadDataPopulatesCurrentMonthMatchingGauge() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)
        // Seed a payment in the current calendar month so the "this month"
        // window picks it up. The dashboard gauge sums the same window.
        let cal = Calendar.current
        let firstBuy = cal.date(byAdding: .month, value: -3, to: .now) ?? .now
        for h in holdings where h.status != .estudo {
            let c = Transaction(date: firstBuy, amount: 1, shares: h.quantity, pricePerShare: h.averagePrice)
            ctx.insert(c); c.holding = h
            let payDate = cal.date(byAdding: .day, value: -1, to: .now) ?? .now
            let exDate = cal.date(byAdding: .day, value: -2, to: .now) ?? .now
            let p = DividendPayment(exDate: exDate, paymentDate: payDate, amountPerShare: 1)
            ctx.insert(p); p.holding = h
        }
        try ctx.save()

        let vm = IncomeTrendsViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        // VM's currentMonth must equal the same IncomeAggregator.summary the
        // gauge consumes — the "merge" contract: gauge and Income screen
        // refer to the same paid+projected number.
        let nonStudy = holdings.filter { $0.status != .estudo }
        let expected = IncomeAggregator.summary(
            holdings: nonStudy, window: .month, in: .brl, rates: Self.rates
        )
        #expect(vm.currentMonth?.total.amount == expected.total.amount)
        #expect(vm.currentMonth?.paid.amount == expected.paid.amount)
        #expect(vm.currentMonth?.projected.amount == expected.projected.amount)
    }

    @MainActor
    @Test func loadDataLoadsMonthlyGoalFromSettings() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx) // seedTestData persists monthlyIncomeGoal: 8000

        let vm = IncomeTrendsViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.monthlyGoal != nil)
        #expect(vm.monthlyGoal?.amount == 8000)
    }

    @MainActor
    @Test func loadDataWithEmptyPortfolio() throws {
        let ctx = try makeTestContext()

        let vm = IncomeTrendsViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.monthlyHistory.allSatisfy { $0.total.amount == 0 })
        #expect(vm.topPayers.isEmpty)
        #expect(vm.concentration?.segments.isEmpty == true)
        #expect(vm.yoyGrowth?.currentTTM.amount == 0)
        #expect(vm.currentMonth?.total.amount == 0)
    }

    @MainActor
    @Test func loadDataSetsLoadingFalse() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)
        Self.seed12MonthlyDividends(ctx, holdings: holdings)

        let vm = IncomeTrendsViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.isLoading == false)
    }
}
