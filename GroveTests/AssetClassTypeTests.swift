import Testing
import Foundation
@testable import Grove

struct AssetClassTypeTests {

    // MARK: - Auto-detection

    @Test func detectsBrazilianStocks() {
        #expect(AssetClassType.detect(from: "ITUB3") == .acoesBR)
        #expect(AssetClassType.detect(from: "PETR4") == .acoesBR)
        #expect(AssetClassType.detect(from: "WEGE3") == .acoesBR)
    }

    @Test func detectsFIIs() {
        #expect(AssetClassType.detect(from: "KNRI11") == .fiis)
        #expect(AssetClassType.detect(from: "BTLG11") == .fiis)
        #expect(AssetClassType.detect(from: "XPML11") == .fiis)
        #expect(AssetClassType.detect(from: "MXRF11") == .fiis)
    }

    @Test func detectsCrypto() {
        #expect(AssetClassType.detect(from: "BTC") == .crypto)
        #expect(AssetClassType.detect(from: "ETH") == .crypto)
        #expect(AssetClassType.detect(from: "SOL") == .crypto)
    }

    @Test func detectsUSStocks() {
        #expect(AssetClassType.detect(from: "AAPL") == .usStocks)
        #expect(AssetClassType.detect(from: "GOOG") == .usStocks)
        #expect(AssetClassType.detect(from: "NVDA") == .usStocks)
    }

    @Test func handlesCaseInsensitive() {
        #expect(AssetClassType.detect(from: "itub3") == .acoesBR)
        #expect(AssetClassType.detect(from: "btc") == .crypto)
    }

    // MARK: - Default Currency

    @Test func brAssetsDefaultToBRL() {
        #expect(AssetClassType.acoesBR.defaultCurrency == .brl)
        #expect(AssetClassType.fiis.defaultCurrency == .brl)
        #expect(AssetClassType.rendaFixa.defaultCurrency == .brl)
    }

    @Test func usAssetsDefaultToUSD() {
        #expect(AssetClassType.usStocks.defaultCurrency == .usd)
        #expect(AssetClassType.reits.defaultCurrency == .usd)
    }

    // MARK: - Tax Treatment

    @Test func exemptAssetsHaveCorrectTreatment() {
        #expect(AssetClassType.fiis.defaultTaxTreatment == .exempt)
        #expect(AssetClassType.acoesBR.defaultTaxTreatment == .exempt)
    }

    @Test func usAssetsHaveNRATreatment() {
        #expect(AssetClassType.usStocks.defaultTaxTreatment == .nra30)
        #expect(AssetClassType.reits.defaultTaxTreatment == .nra30)
    }
}
