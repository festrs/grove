import Testing
import Foundation
import SwiftData
import GroveDomain
import GroveServices
@testable import Grove

@Suite(.serialized)
struct RebalancingViewModelTests {

    private static let rates: any ExchangeRates = StaticRates(brlPerUsd: 5)

    // MARK: - investmentAmount parsing

    @Test func investmentAmountParsesPlainNumber() {
        let vm = RebalancingViewModel()
        vm.investmentAmountText = "5000"
        #expect(vm.investmentAmountDecimal == 5000)
    }

    @Test func investmentAmountParsesBrazilianFormat() {
        let vm = RebalancingViewModel()
        vm.investmentAmountText = "5.000,50"
        #expect(vm.investmentAmountDecimal == Decimal(string: "5000.50"))
    }

    @Test func investmentAmountReturnsZeroForEmpty() {
        let vm = RebalancingViewModel()
        vm.investmentAmountText = ""
        #expect(vm.investmentAmountDecimal == 0)
    }

    @Test func investmentAmountReturnsZeroForInvalid() {
        let vm = RebalancingViewModel()
        vm.investmentAmountText = "abc"
        #expect(vm.investmentAmountDecimal == 0)
    }

    // MARK: - Initial state

    @Test func initialState() {
        let vm = RebalancingViewModel()
        #expect(vm.investmentAmountText == "")
        #expect(vm.suggestions.isEmpty)
        #expect(vm.totalAllocated.amount == 0)
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
        vm.calculate(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.hasCalculated == true)
        #expect(!vm.suggestions.isEmpty)
        #expect(vm.totalAllocated.amount > 0)
    }

    @MainActor
    @Test func calculateWithZeroAmountProducesEmpty() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "0"
        vm.calculate(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

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
        vm.calculate(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

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
        vm.calculate(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.hasCalculated == true)
        #expect(vm.suggestions.isEmpty)
        #expect(vm.emptyReason == .noAportarHoldings)
    }

    @MainActor
    @Test func zeroQuantityAportarHoldingStillRecommended() throws {
        let ctx = try makeTestContext()
        let portfolio = Portfolio(name: "Test")
        ctx.insert(portfolio)

        let h = Holding(ticker: "TEST3.SA", displayName: "Test", currentPrice: 50, assetClass: .acoesBR, status: .aportar)
        ctx.insert(h)
        h.portfolio = portfolio

        let settings = UserSettings(hasCompletedOnboarding: true)
        settings.classAllocations = [.acoesBR: 100]
        ctx.insert(settings)
        try ctx.save()

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "1000"
        vm.calculate(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.hasCalculated == true)
        #expect(!vm.suggestions.isEmpty)
        #expect(vm.emptyReason == nil)
    }

    @MainActor
    @Test func emptyReasonSetOnZeroAmount() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "0"
        vm.calculate(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)

        #expect(vm.hasCalculated == true)
        #expect(vm.suggestions.isEmpty)
        #expect(vm.emptyReason != nil)
    }

    // MARK: - registerContributions

    @MainActor
    @Test func registerContributionsClearsState() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "5000"
        vm.calculate(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)
        #expect(!vm.suggestions.isEmpty)

        vm.registerContributions(modelContext: ctx)

        #expect(vm.suggestions.isEmpty)
        #expect(vm.investmentAmountText == "")
        #expect(vm.hasCalculated == false)
    }

    // MARK: - editedShares / effectiveShares

    @Test func effectiveSharesReturnsEngineDefaultWhenNoOverride() {
        let vm = RebalancingViewModel()
        let suggestion = makeSuggestion(ticker: "ITUB3", shares: 10)
        #expect(vm.effectiveShares(for: suggestion) == 10)
    }

    @Test func effectiveSharesReturnsOverrideAfterSet() {
        let vm = RebalancingViewModel()
        let suggestion = makeSuggestion(ticker: "ITUB3", shares: 10)
        vm.setShares(7, for: suggestion)
        #expect(vm.effectiveShares(for: suggestion) == 7)
    }

    @Test func setSharesClampsNegativeToZero() {
        let vm = RebalancingViewModel()
        let suggestion = makeSuggestion(ticker: "ITUB3", shares: 10)
        vm.setShares(-5, for: suggestion)
        #expect(vm.effectiveShares(for: suggestion) == 0)
    }

    @Test func effectiveAmountScalesWithEditedShares() {
        let vm = RebalancingViewModel()
        // 10 shares @ R$32 = R$320
        let suggestion = makeSuggestion(ticker: "ITUB3", shares: 10, pricePerShare: 32)
        let original = vm.effectiveAmount(for: suggestion)
        #expect(original.amount == 320)

        vm.setShares(5, for: suggestion)
        let halved = vm.effectiveAmount(for: suggestion)
        #expect(halved.amount == 160)
    }

    @Test func effectiveAmountIsZeroWhenSharesSetToZero() {
        let vm = RebalancingViewModel()
        let suggestion = makeSuggestion(ticker: "ITUB3", shares: 10, pricePerShare: 32)
        vm.setShares(0, for: suggestion)
        #expect(vm.effectiveAmount(for: suggestion).amount == 0)
    }

    @MainActor
    @Test func calculateClearsEditedShares() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "5000"
        vm.calculate(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)
        guard let first = vm.suggestions.first else { return }
        vm.setShares(99, for: first)
        #expect(vm.editedShares[first.ticker] == 99)

        vm.calculate(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)
        #expect(vm.editedShares.isEmpty)
    }

    @MainActor
    @Test func registerUsesEditedShareCount() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "5000"
        vm.calculate(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)
        guard let first = vm.suggestions.first else { return }

        vm.setShares(3, for: first)
        vm.registerContributions(modelContext: ctx)

        let ticker = first.ticker
        let descriptor = FetchDescriptor<Holding>(predicate: #Predicate { $0.ticker == ticker })
        guard let holding = try ctx.fetch(descriptor).first else { return }
        let txns = holding.transactions
        #expect(txns.contains { $0.shares == 3 })
        _ = holdings // suppress unused warning
    }

    @MainActor
    @Test func registerSkipsSuggestionWithZeroShares() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "5000"
        vm.calculate(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)
        guard let first = vm.suggestions.first else { return }

        vm.setShares(0, for: first)
        vm.registerContributions(modelContext: ctx)

        let ticker = first.ticker
        let descriptor = FetchDescriptor<Holding>(predicate: #Predicate { $0.ticker == ticker })
        guard let holding = try ctx.fetch(descriptor).first else { return }
        let txns = holding.transactions
        #expect(txns.isEmpty)
        _ = holdings
    }

    @MainActor
    @Test func registerClearsEditedShares() throws {
        let ctx = try makeTestContext()
        let (_, _) = seedTestData(ctx)

        let vm = RebalancingViewModel()
        vm.investmentAmountText = "5000"
        vm.calculate(modelContext: ctx, displayCurrency: .brl, rates: Self.rates)
        if let first = vm.suggestions.first { vm.setShares(2, for: first) }

        vm.registerContributions(modelContext: ctx)
        #expect(vm.editedShares.isEmpty)
    }

    // MARK: - Helpers

    private func makeSuggestion(ticker: String, shares: Int, pricePerShare: Decimal = 32) -> RebalancingSuggestion {
        RebalancingSuggestion(
            ticker: ticker,
            displayName: ticker,
            sharesToBuy: shares,
            amount: Money(amount: Decimal(shares) * pricePerShare, currency: .brl),
            currentPercent: 10,
            targetPercent: 25,
            newPercent: 18
        )
    }
}
