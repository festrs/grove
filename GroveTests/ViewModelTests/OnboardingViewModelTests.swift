import Testing
import Foundation
import SwiftData
import GroveDomain
@testable import Grove

struct OnboardingViewModelTests {

    // MARK: - Navigation

    @Test func initialStepIsZero() {
        let vm = OnboardingViewModel()
        #expect(vm.currentStep == 0)
    }

    @Test func advanceIncrementsStep() {
        let vm = OnboardingViewModel()
        vm.advance()
        #expect(vm.currentStep == 1)
    }

    @Test func advanceDoesNotExceedMaxStep() {
        let vm = OnboardingViewModel()
        for _ in 0..<10 {
            vm.advance()
        }
        #expect(vm.currentStep == OnboardingViewModel.totalSteps - 1)
    }

    @Test func goBackDecrementsStep() {
        let vm = OnboardingViewModel()
        vm.advance()
        vm.advance()
        vm.goBack()
        #expect(vm.currentStep == 1)
    }

    @Test func goBackDoesNotGoBelowZero() {
        let vm = OnboardingViewModel()
        vm.goBack()
        #expect(vm.currentStep == 0)
    }

    // MARK: - canAdvance

    @Test func canAdvanceStep0AlwaysTrue() {
        let vm = OnboardingViewModel()
        #expect(vm.canAdvance == true)
    }

    @Test func canAdvanceStep1RequiresHoldings() {
        let vm = OnboardingViewModel()
        vm.currentStep = 1
        #expect(vm.canAdvance == false)

        vm.addHolding(ticker: "ITUB3")
        #expect(vm.canAdvance == true)
    }

    @Test func canAdvanceStep3RequiresValidTarget() {
        let vm = OnboardingViewModel()
        vm.currentStep = 3
        vm.addHolding(ticker: "ITUB3")
        // Only acoesBR is in use — set its allocation to 100 so total = 100
        vm.targetAllocations = [.acoesBR: 100]
        #expect(vm.canAdvance == true)

        vm.targetAllocations = [.acoesBR: 50] // only 50, not 100
        #expect(vm.canAdvance == false)
    }

    // MARK: - Holdings Management

    @Test func addHoldingFromSearchResult() {
        let vm = OnboardingViewModel()
        let result = StockSearchResultDTO(id: "ITUB3.SA", symbol: "ITUB3.SA", name: "Itau", type: "stock", price: "32", currency: "BRL", change: nil, sector: nil, logo: nil)
        vm.addHolding(from: result)

        #expect(vm.pendingHoldings.count == 1)
        #expect(vm.pendingHoldings[0].ticker == "ITUB3.SA")
        #expect(vm.pendingHoldings[0].quantity == 0)
        #expect(vm.pendingHoldings[0].status == .estudo)
    }

    @Test func addHoldingFromTicker() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "PETR4")

        #expect(vm.pendingHoldings.count == 1)
        #expect(vm.pendingHoldings[0].ticker == "PETR4")
        #expect(vm.pendingHoldings[0].assetClass == .acoesBR)
        #expect(vm.pendingHoldings[0].status == .estudo)
    }

    @Test func addHoldingPreventsDuplicates() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "ITUB3")
        vm.addHolding(ticker: "ITUB3")

        #expect(vm.pendingHoldings.count == 1)
        #expect(vm.errorMessage != nil)
    }

    @Test func addHoldingRespectsFreeTierLimit() {
        UserDefaults.standard.set(false, forKey: AppConstants.Debug.unlimitedHoldingsKey)
        let vm = OnboardingViewModel()
        for i in 0..<AppConstants.freeTierMaxHoldings {
            vm.addHolding(ticker: "T\(i)")
        }
        #expect(vm.pendingHoldings.count == AppConstants.freeTierMaxHoldings)
        #expect(vm.canAddMoreHoldings == false)

        vm.addHolding(ticker: "EXTRA")
        #expect(vm.pendingHoldings.count == AppConstants.freeTierMaxHoldings)
        #expect(vm.errorMessage != nil)
    }

    @Test func addHoldingFromSearchRespectsFreeTierLimit() {
        UserDefaults.standard.set(false, forKey: AppConstants.Debug.unlimitedHoldingsKey)
        let vm = OnboardingViewModel()
        for i in 0..<AppConstants.freeTierMaxHoldings {
            vm.addHolding(ticker: "T\(i)")
        }
        #expect(vm.canAddMoreHoldings == false)

        let result = StockSearchResultDTO(id: "EXTRA.SA", symbol: "EXTRA.SA", name: "Extra", type: "stock", price: "10", currency: "BRL", change: nil, sector: nil, logo: nil)
        vm.addHolding(from: result)

        #expect(vm.pendingHoldings.count == AppConstants.freeTierMaxHoldings, "Should not exceed limit via search")
        #expect(vm.errorMessage != nil)
    }

    @Test func addHoldingIgnoresEmptyTicker() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "  ")
        #expect(vm.pendingHoldings.isEmpty)
    }

    @Test func removeHoldingByOffset() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "A")
        vm.addHolding(ticker: "B")
        vm.removeHolding(at: IndexSet(integer: 0))

        #expect(vm.pendingHoldings.count == 1)
        #expect(vm.pendingHoldings[0].ticker == "B")
    }

    @Test func removeHoldingByID() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "A")
        let id = vm.pendingHoldings[0].id
        vm.removeHolding(id: id)

        #expect(vm.pendingHoldings.isEmpty)
    }

    // MARK: - Computed Properties

    @Test func holdingCount() {
        let vm = OnboardingViewModel()
        #expect(vm.holdingCount == 0)
        vm.addHolding(ticker: "X")
        #expect(vm.holdingCount == 1)
    }

    @Test func assetClassesInUse() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "ITUB3") // acoesBR
        vm.addHolding(ticker: "KNRI11") // fiis

        let classes = vm.assetClassesInUse
        #expect(classes.contains(.acoesBR))
        #expect(classes.contains(.fiis))
        #expect(!classes.contains(.usStocks))
    }

    @Test func totalTargetAllocationCoversAllSixClasses() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "ITUB3") // acoesBR
        // Defaults sum to 100 across the full universe, regardless of which
        // classes the user has pending holdings in.
        #expect(vm.totalTargetAllocation == 100)
    }

    @Test func isTargetValidWhenSumIs100() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "ITUB3")
        vm.targetAllocations = [.acoesBR: 100]
        #expect(vm.isTargetValid == true)
    }

    @Test func isTargetInvalidWhenSumIsNot100() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "ITUB3")
        vm.targetAllocations = [.acoesBR: 50]
        #expect(vm.isTargetValid == false)
    }

    // MARK: - Auto-classify

    @Test func autoClassifyAll() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "KNRI11")
        // Initially detected as fiis from ticker heuristic
        vm.pendingHoldings[0].assetClass = .acoesBR // manually override to wrong class
        vm.autoClassifyAll()
        #expect(vm.pendingHoldings[0].assetClass == .fiis)
    }

    @Test func importFromCSVAddsHoldings() {
        let vm = OnboardingViewModel()
        vm.csvText = "ITUB3\nPETR4\nBTLG11"
        vm.importFromCSV()
        #expect(vm.pendingHoldings.count == 3)
        #expect(vm.errorMessage == nil)
    }

    @Test func importFromCSVSkipsDuplicates() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "ITUB3")
        vm.csvText = "ITUB3\nPETR4"
        vm.importFromCSV()
        #expect(vm.pendingHoldings.count == 2) // ITUB3 skipped, PETR4 added
    }

    @Test func importFromCSVShowsErrorOnEmpty() {
        let vm = OnboardingViewModel()
        vm.csvText = "12345"
        vm.importFromCSV()
        #expect(vm.errorMessage != nil)
    }

    // MARK: - Search (async)

    @Test func searchWithEmptyQueryClearsResults() async {
        let vm = OnboardingViewModel()
        let mock = MockBackendService()
        await vm.searchTicker(query: "", service: mock)
        #expect(vm.searchResults.isEmpty)
    }

    @Test func searchSetsIsSearching() async {
        let vm = OnboardingViewModel()
        let mock = MockBackendService()
        await vm.searchTicker(query: "ITUB", service: mock)
        // After completion, isSearching should be false
        #expect(vm.isSearching == false)
        #expect(!vm.searchResults.isEmpty)
    }

    // MARK: - completeOnboarding

    @MainActor
    @Test func completeOnboardingPreservesPendingStatus() throws {
        let ctx = try makeTestContext()
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "ITUB3")
        // User explicitly promotes the holding from .estudo to .aportar before finishing.
        vm.pendingHoldings[0].status = .aportar
        vm.targetAllocations = [.acoesBR: 100]

        vm.completeOnboarding(modelContext: ctx, backendService: MockBackendService())

        let saved = try ctx.fetch(FetchDescriptor<Holding>())
        #expect(saved.count == 1)
        // Mutation "completeOnboarding ignores status" hard-codes .estudo here.
        #expect(saved.first?.status == .aportar, "Onboarding must persist the user-picked status verbatim")
    }
}
