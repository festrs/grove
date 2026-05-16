import Testing
import Foundation
@testable import GroveDomain

@Suite struct AssetClassAllocationsTests {

    @Test func defaultZerosCoversEveryAssetClass() {
        let zeros = [AssetClassType: Double].defaultAssetClassZeros
        for cls in AssetClassType.allCases {
            #expect(zeros[cls] == 0)
        }
        #expect(zeros.count == AssetClassType.allCases.count)
    }

    @Test func withMissingZerosFillsGapsButPreservesExisting() {
        let partial: [AssetClassType: Double] = [.acoesBR: 60, .fiis: 40]
        let filled = partial.withMissingAssetClassZeros
        #expect(filled[.acoesBR] == 60)
        #expect(filled[.fiis] == 40)
        #expect(filled[.usStocks] == 0)
        #expect(filled.count == AssetClassType.allCases.count)
    }

    @Test func totalSumsAllValues() {
        let weights: [AssetClassType: Double] = [.acoesBR: 60, .fiis: 30, .usStocks: 10]
        #expect(weights.allocationTotal == 100)
    }

    @Test func isValidAllocationWhenSumIs100() {
        let weights: [AssetClassType: Double] = [.acoesBR: 60, .fiis: 40]
        #expect(weights.isValidAllocation == true)
    }

    @Test func isInvalidAllocationWhenSumNot100() {
        let under: [AssetClassType: Double] = [.acoesBR: 60, .fiis: 20]
        #expect(under.isValidAllocation == false)
        let over: [AssetClassType: Double] = [.acoesBR: 60, .fiis: 60]
        #expect(over.isValidAllocation == false)
    }

    @Test func isValidAllocationTolerates_smallFloatDrift() {
        let weights: [AssetClassType: Double] = [.acoesBR: 33.4, .fiis: 33.3, .usStocks: 33.3]
        // 100.0 exactly (within tolerance)
        #expect(weights.isValidAllocation == true)
    }
}
