import Testing
import Foundation
import SwiftData
@testable import Tranquilidade

@Suite(.serialized)
struct HoldingDetailViewModelTests {

    // MARK: - Initial state

    @Test func initialState() {
        let vm = HoldingDetailViewModel()
        #expect(vm.holding == nil)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    // MARK: - loadHolding

    @MainActor
    @Test func loadHoldingFindsHolding() throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)
        let holdingID = holdings[0].persistentModelID

        let vm = HoldingDetailViewModel()
        vm.loadHolding(id: holdingID, modelContext: ctx)

        #expect(vm.holding != nil)
        #expect(vm.holding!.ticker == "ITUB3.SA")
    }

    // MARK: - updatePrice

    @MainActor
    @Test func updatePriceSetsLoadingState() async throws {
        let ctx = try makeTestContext()
        let (_, holdings) = seedTestData(ctx)

        let vm = HoldingDetailViewModel()
        vm.loadHolding(id: holdings[0].persistentModelID, modelContext: ctx)

        let mock = MockBackendService()
        await vm.updatePrice(backendService: mock)

        #expect(vm.isLoading == false)
        #expect(vm.holding!.lastPriceUpdate != nil)
    }

    @MainActor
    @Test func updatePriceWithNoHoldingDoesNothing() async {
        let vm = HoldingDetailViewModel()
        let mock = MockBackendService()
        await vm.updatePrice(backendService: mock)

        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }
}
