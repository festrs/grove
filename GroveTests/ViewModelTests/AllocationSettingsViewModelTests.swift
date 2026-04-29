import Testing
import Foundation
import SwiftData
import GroveDomain
@testable import Grove

@Suite(.serialized)
struct AllocationSettingsViewModelTests {

    // MARK: - Initial state

    @MainActor
    @Test func initialStateAllZeros() {
        let vm = AllocationSettingsViewModel()
        #expect(vm.weights.isEmpty == false, "All asset classes initialised to 0")
        for cls in AssetClassType.allCases {
            #expect(vm.weights[cls] == 0)
        }
        #expect(vm.hasChanges == false)
        #expect(vm.total == 0)
        #expect(vm.isValid == false)
    }

    // MARK: - load

    @MainActor
    @Test func loadReadsExistingAllocations() throws {
        let ctx = try makeTestContext()
        let settings = UserSettings()
        settings.classAllocations = [.acoesBR: 60, .fiis: 40]
        ctx.insert(settings)
        try ctx.save()

        let vm = AllocationSettingsViewModel()
        vm.load(modelContext: ctx)

        #expect(vm.weights[.acoesBR] == 60)
        #expect(vm.weights[.fiis] == 40)
        #expect(vm.weights[.usStocks] == 0, "Missing classes default to 0 so steppers render correctly")
        #expect(vm.hasChanges == false)
    }

    // MARK: - validity

    @MainActor
    @Test func isValidWhenTotalIs100() {
        let vm = AllocationSettingsViewModel()
        vm.setWeight(60, for: .acoesBR)
        vm.setWeight(40, for: .fiis)
        #expect(vm.total == 100)
        #expect(vm.isValid == true)
    }

    @MainActor
    @Test func isInvalidWhenTotalNot100() {
        let vm = AllocationSettingsViewModel()
        vm.setWeight(60, for: .acoesBR)
        vm.setWeight(20, for: .fiis)
        #expect(vm.total == 80)
        #expect(vm.isValid == false)
    }

    @MainActor
    @Test func setWeightFlipsHasChanges() {
        let vm = AllocationSettingsViewModel()
        #expect(vm.hasChanges == false)
        vm.setWeight(50, for: .acoesBR)
        #expect(vm.hasChanges == true)
    }

    // MARK: - save

    @MainActor
    @Test func savePersistsAndClearsHasChanges() throws {
        let ctx = try makeTestContext()
        let settings = UserSettings()
        ctx.insert(settings)
        try ctx.save()

        let vm = AllocationSettingsViewModel()
        vm.load(modelContext: ctx)
        vm.setWeight(50, for: .acoesBR)
        vm.setWeight(50, for: .fiis)

        let saved = vm.save(modelContext: ctx)
        #expect(saved == true)
        #expect(vm.hasChanges == false)

        let stored = try ctx.fetch(FetchDescriptor<UserSettings>()).first!.classAllocations
        #expect(stored[.acoesBR] == 50)
        #expect(stored[.fiis] == 50)
    }

    @MainActor
    @Test func saveRejectedWhenInvalid() throws {
        let ctx = try makeTestContext()
        let settings = UserSettings()
        settings.classAllocations = [.acoesBR: 100]
        ctx.insert(settings)
        try ctx.save()

        let vm = AllocationSettingsViewModel()
        vm.load(modelContext: ctx)
        vm.setWeight(80, for: .acoesBR)  // total 80 — invalid

        let saved = vm.save(modelContext: ctx)
        #expect(saved == false, "Save must refuse to write a non-100 total")
        let stored = try ctx.fetch(FetchDescriptor<UserSettings>()).first!.classAllocations
        #expect(stored[.acoesBR] == 100, "Stored allocation untouched on rejected save")
    }
}
