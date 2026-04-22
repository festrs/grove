import Testing
import Foundation
@testable import Tranquilidade

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

        vm.addHolding(ticker: "ITUB3", quantity: 100)
        #expect(vm.canAdvance == true)
    }

    @Test func canAdvanceStep3RequiresValidTarget() {
        let vm = OnboardingViewModel()
        vm.currentStep = 3
        vm.addHolding(ticker: "ITUB3", quantity: 100)
        // Default allocations sum to 100
        #expect(vm.canAdvance == true)

        vm.targetAllocations = [.acoesBR: 50] // only 50, not 100
        #expect(vm.canAdvance == false)
    }

    // MARK: - Holdings Management

    @Test func addHoldingFromSearchResult() {
        let vm = OnboardingViewModel()
        let result = StockSearchResultDTO(id: "ITUB3.SA", symbol: "ITUB3.SA", name: "Itau", type: "stock", price: "32", currency: "BRL", change: nil, sector: nil, logo: nil)
        vm.addHolding(from: result, quantity: 100)

        #expect(vm.pendingHoldings.count == 1)
        #expect(vm.pendingHoldings[0].ticker == "ITUB3.SA")
        #expect(vm.pendingHoldings[0].quantity == 100)
    }

    @Test func addHoldingFromTicker() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "PETR4", quantity: 200)

        #expect(vm.pendingHoldings.count == 1)
        #expect(vm.pendingHoldings[0].ticker == "PETR4")
        #expect(vm.pendingHoldings[0].assetClass == .acoesBR)
    }

    @Test func addHoldingPreventsDuplicates() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "ITUB3", quantity: 100)
        vm.addHolding(ticker: "ITUB3", quantity: 200)

        #expect(vm.pendingHoldings.count == 1)
        #expect(vm.errorMessage != nil)
    }

    @Test func addHoldingRespectsFreeTierLimit() {
        let vm = OnboardingViewModel()
        for i in 0..<AppConstants.freeTierMaxHoldings {
            vm.addHolding(ticker: "T\(i)", quantity: 1)
        }
        #expect(vm.pendingHoldings.count == AppConstants.freeTierMaxHoldings)
        #expect(vm.canAddMoreHoldings == false)

        vm.addHolding(ticker: "EXTRA", quantity: 1)
        #expect(vm.pendingHoldings.count == AppConstants.freeTierMaxHoldings)
        #expect(vm.errorMessage != nil)
    }

    @Test func addHoldingIgnoresEmptyTicker() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "  ", quantity: 100)
        #expect(vm.pendingHoldings.isEmpty)
    }

    @Test func removeHoldingByOffset() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "A", quantity: 1)
        vm.addHolding(ticker: "B", quantity: 1)
        vm.removeHolding(at: IndexSet(integer: 0))

        #expect(vm.pendingHoldings.count == 1)
        #expect(vm.pendingHoldings[0].ticker == "B")
    }

    @Test func removeHoldingByID() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "A", quantity: 1)
        let id = vm.pendingHoldings[0].id
        vm.removeHolding(id: id)

        #expect(vm.pendingHoldings.isEmpty)
    }

    // MARK: - Computed Properties

    @Test func holdingCount() {
        let vm = OnboardingViewModel()
        #expect(vm.holdingCount == 0)
        vm.addHolding(ticker: "X", quantity: 1)
        #expect(vm.holdingCount == 1)
    }

    @Test func assetClassesInUse() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "ITUB3", quantity: 100) // acoesBR
        vm.addHolding(ticker: "KNRI11", quantity: 50) // fiis

        let classes = vm.assetClassesInUse
        #expect(classes.contains(.acoesBR))
        #expect(classes.contains(.fiis))
        #expect(!classes.contains(.usStocks))
    }

    @Test func totalTargetAllocationOnlyCountsUsedClasses() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "ITUB3", quantity: 100) // acoesBR
        // Default targetAllocations[.acoesBR] = 30
        #expect(vm.totalTargetAllocation == 30)
    }

    @Test func isTargetValidWhenSumIs100() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "ITUB3", quantity: 100)
        vm.targetAllocations = [.acoesBR: 100]
        #expect(vm.isTargetValid == true)
    }

    @Test func isTargetInvalidWhenSumIsNot100() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "ITUB3", quantity: 100)
        vm.targetAllocations = [.acoesBR: 50]
        #expect(vm.isTargetValid == false)
    }

    // MARK: - Auto-classify

    @Test func autoClassifyAll() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "KNRI11", quantity: 50)
        // Initially detected as fiis from ticker heuristic
        vm.pendingHoldings[0].assetClass = .acoesBR // manually override to wrong class
        vm.autoClassifyAll()
        #expect(vm.pendingHoldings[0].assetClass == .fiis)
    }

    // MARK: - CSV Parsing

    @Test func parseCSVWithComma() {
        let vm = OnboardingViewModel()
        let result = vm.parseCSV("ITUB3, 100\nPETR4, 200")
        #expect(result.count == 2)
        #expect(result[0].0 == "ITUB3")
        #expect(result[0].1 == 100)
        #expect(result[1].0 == "PETR4")
        #expect(result[1].1 == 200)
    }

    @Test func parseCSVWithSemicolon() {
        let vm = OnboardingViewModel()
        let result = vm.parseCSV("ITUB3;100")
        #expect(result.count == 1)
        #expect(result[0].0 == "ITUB3")
    }

    @Test func parseCSVWithTab() {
        let vm = OnboardingViewModel()
        let result = vm.parseCSV("ITUB3\t100")
        #expect(result.count == 1)
    }

    @Test func parseCSVSkipsEmptyLinesAndInvalid() {
        let vm = OnboardingViewModel()
        let result = vm.parseCSV("\n\nITUB3, 100\nbadline\n\n")
        #expect(result.count == 1)
    }

    @Test func parseCSVSkipsZeroQuantity() {
        let vm = OnboardingViewModel()
        let result = vm.parseCSV("ITUB3, 0")
        #expect(result.isEmpty)
    }

    @Test func importFromCSVAddsHoldings() {
        let vm = OnboardingViewModel()
        vm.csvText = "ITUB3, 100\nPETR4, 200"
        vm.importFromCSV()
        #expect(vm.pendingHoldings.count == 2)
        #expect(vm.errorMessage == nil)
    }

    @Test func importFromCSVSkipsDuplicates() {
        let vm = OnboardingViewModel()
        vm.addHolding(ticker: "ITUB3", quantity: 50)
        vm.csvText = "ITUB3, 100\nPETR4, 200"
        vm.importFromCSV()
        #expect(vm.pendingHoldings.count == 2) // ITUB3 skipped, PETR4 added
    }

    @Test func importFromCSVShowsErrorOnEmpty() {
        let vm = OnboardingViewModel()
        vm.csvText = "invalid data"
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
}
