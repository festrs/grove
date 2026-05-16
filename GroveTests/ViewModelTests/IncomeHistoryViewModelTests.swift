import Testing
import Foundation
import SwiftData
import GroveDomain
import GroveServices
@testable import Grove

@Suite(.serialized)
struct IncomeHistoryViewModelTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    /// 2026-04-29-ish timestamp; .now is fine here since we just need
    /// "current month" to actually be the current month for the VM call.
    @MainActor
    private static func seedDividendsForCurrentMonth(_ ctx: ModelContext, holdings: [Holding]) {
        let firstBuy = Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .now
        let payDate = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        let exDate = Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now

        for h in holdings where h.status != .estudo {
            let c = Transaction(date: firstBuy, amount: 1, shares: h.quantity, pricePerShare: h.averagePrice)
            ctx.insert(c); c.holding = h
            let p = DividendPayment(exDate: exDate, paymentDate: payDate, amountPerShare: 1)
            ctx.insert(p); p.holding = h
        }
        try? ctx.save()
    }

    // MARK: - Initial state

    @MainActor
    @Test func initialState() {
        let vm = IncomeHistoryViewModel()
        #expect(vm.summaries.isEmpty)
        #expect(vm.byClass.isEmpty)
        #expect(vm.taxBreakdown == nil)
        #expect(vm.isLoading == false)
        #expect(vm.selectedWindow == .year)
    }

    // MARK: - loadData

    @MainActor
    @Test func loadDataPopulatesSummariesAndByClass() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)
        Self.seedDividendsForCurrentMonth(ctx, holdings: holdings)

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        // Four windows always emitted: day/week/month/year
        #expect(vm.summaries.count == 4)
        #expect(vm.summaries.map(\.window) == [.day, .week, .month, .year])
        // At least the year summary should pick up our seeded payments
        let year = vm.summaries.first { $0.window == .year }!
        #expect(year.total.amount > 0)
        #expect(!vm.byClass.isEmpty)
    }

    @MainActor
    @Test func loadDataPopulatesTaxBreakdown() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)
        Self.seedDividendsForCurrentMonth(ctx, holdings: holdings)

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.taxBreakdown != nil)
        #expect(vm.taxBreakdown!.totalNet.amount > 0)
    }

    @MainActor
    @Test func loadDataSortsByClassDescendingByTotal() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)
        Self.seedDividendsForCurrentMonth(ctx, holdings: holdings)

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        for i in 0..<vm.byClass.count - 1 {
            let lhs = vm.byClass[i].total.converted(to: .brl, using: Self.rates).amount
            let rhs = vm.byClass[i + 1].total.converted(to: .brl, using: Self.rates).amount
            #expect(lhs >= rhs)
        }
    }

    @MainActor
    @Test func loadDataWithEmptyPortfolio() throws {
        let ctx = try makeTestContext()

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        // Four zero summaries are still emitted.
        #expect(vm.summaries.count == 4)
        #expect(vm.summaries.allSatisfy { $0.total.amount == 0 })
        #expect(vm.byClass.isEmpty)
    }

    @MainActor
    @Test func loadDataSetsLoadingFalse() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)
        Self.seedDividendsForCurrentMonth(ctx, holdings: holdings)

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.isLoading == false)
    }

    @MainActor
    @Test func selectWindowReloadsByClass() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)
        Self.seedDividendsForCurrentMonth(ctx, holdings: holdings)

        let vm = IncomeHistoryViewModel()
        vm.loadData(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)
        vm.selectWindow(.month, modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.selectedWindow == .month)
        // Month window should still pick up the very-recent payments seeded above
        #expect(!vm.byClass.isEmpty)
    }
}
