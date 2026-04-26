import Testing
import Foundation
import SwiftData
@testable import Grove

@Suite(.serialized)
struct RebalancingViewModelTests {

    // MARK: - investmentAmount parsing

    @Test func investmentAmountParsesPlainNumber() {
        let vm = RebalancingViewModel()
        vm.investmentAmountText = "5000"
        #expect(vm.investmentAmount == 5000)
    }

    @Test func investmentAmountParsesBrazilianFormat() {
        let vm = RebalancingViewModel()
        vm.investmentAmountText = "5.000,50"
        #expect(vm.investmentAmount == Decimal(string: "5000.50"))
    }

    @Test func investmentAmountReturnsZeroForEmpty() {
        let vm = RebalancingViewModel()
        vm.investmentAmountText = ""
        #expect(vm.investmentAmount == 0)
    }

    @Test func investmentAmountReturnsZeroForInvalid() {
        let vm = RebalancingViewModel()
        vm.investmentAmountText = "abc"
        #expect(vm.investmentAmount == 0)
    }

    // MARK: - Initial state

    @Test func initialState() {
        let vm = RebalancingViewModel()
        #expect(vm.investmentAmountText == "")
        #expect(vm.suggestions.isEmpty)
        #expect(vm.totalAllocated == 0)
        #expect(vm.hasCalculated == false)
        #expect(vm.isRegistering == false)
    }

    // MARK: - calculate with ModelContext

    @MainActor
    @Test func calculateProducesSuggestions() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "5000"
        vm.calculate(modelContext: ctx)

        #expect(vm.hasCalculated == true)
        #expect(!vm.suggestions.isEmpty)
        #expect(vm.totalAllocated > 0)
    }

    @MainActor
    @Test func calculateWithZeroAmountProducesEmpty() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "0"
        vm.calculate(modelContext: ctx)

        #expect(vm.hasCalculated == true)
        #expect(vm.suggestions.isEmpty)
    }

    // MARK: - emptyReason diagnostics

    @MainActor
    @Test func emptyReasonIsNilWhenSuggestionsExist() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "5000"
        vm.calculate(modelContext: ctx)

        #expect(vm.emptyReason == nil)
        #expect(!vm.suggestions.isEmpty)
    }

    @MainActor
    @Test func emptyReasonNoAportarWhenAllEstudo() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Test")
        ctx.insert(portfolio)

        let h = Holding(ticker: "TEST3.SA", displayName: "Test", currentPrice: 50, assetClass: .acoesBR, status: .estudo)
        ctx.insert(h)
        h.portfolio = portfolio

        let settings = UserSettings(hasCompletedOnboarding: true)
        settings.classAllocations = [.acoesBR: 100]
        ctx.insert(settings)
        try ctx.save()

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "1000"
        vm.calculate(modelContext: ctx)

        #expect(vm.hasCalculated == true)
        #expect(vm.suggestions.isEmpty)
        #expect(vm.emptyReason == .noAportarHoldings)
    }

    @MainActor
    @Test func emptyReasonNoPortfolioValueWhenZeroQuantity() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Test")
        ctx.insert(portfolio)

        // Aportar status but quantity = 0 → currentValue = 0
        let h = Holding(ticker: "TEST3.SA", displayName: "Test", currentPrice: 50, assetClass: .acoesBR, status: .aportar)
        ctx.insert(h)
        h.portfolio = portfolio

        let settings = UserSettings(hasCompletedOnboarding: true)
        settings.classAllocations = [.acoesBR: 100]
        ctx.insert(settings)
        try ctx.save()

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "1000"
        vm.calculate(modelContext: ctx)

        #expect(vm.hasCalculated == true)
        #expect(vm.suggestions.isEmpty)
        #expect(vm.emptyReason == .noPortfolioValue)
    }

    @MainActor
    @Test func emptyReasonSetOnZeroAmount() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "0"
        vm.calculate(modelContext: ctx)

        #expect(vm.hasCalculated == true)
        #expect(vm.suggestions.isEmpty)
        // Zero amount returns empty from engine, emptyReason diagnoses the state
        #expect(vm.emptyReason != nil)
    }

    // MARK: - registerContributions

    @MainActor
    @Test func registerContributionsClearsState() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "5000"
        vm.calculate(modelContext: ctx)
        #expect(!vm.suggestions.isEmpty)

        vm.registerContributions(modelContext: ctx)

        #expect(vm.suggestions.isEmpty)
        #expect(vm.investmentAmountText == "")
        #expect(vm.hasCalculated == false)
    }
}
