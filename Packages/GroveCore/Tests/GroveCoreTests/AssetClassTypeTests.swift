import Testing
import Foundation
import GroveDomain

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

    // MARK: - apiType-driven detection (yfinance/backend search)

    // The unified search endpoint emits the strings below in the `type`
    // field; iOS must keep mapping them to the right asset class so search
    // results render with the correct badge/destination class screen.

    @Test func detectsFromApiTypeStock() {
        #expect(AssetClassType.detect(from: "PETR4.SA", apiType: "stock") == .acoesBR)
    }

    @Test func detectsFromApiTypeFund() {
        #expect(AssetClassType.detect(from: "BTLG11.SA", apiType: "fund") == .fiis)
    }

    @Test func detectsFromApiTypeBdr() {
        #expect(AssetClassType.detect(from: "AAPL34.SA", apiType: "bdr") == .usStocks)
    }

    @Test func detectsFromApiTypeReit() {
        #expect(AssetClassType.detect(from: "O", apiType: "reit") == .reits)
    }

    @Test func detectsFromApiTypeCommonStock() {
        // Backend emits "common stock" verbatim for US equities; the
        // case-insensitive match in detect() also handles "Common Stock".
        #expect(AssetClassType.detect(from: "AAPL", apiType: "common stock") == .usStocks)
        #expect(AssetClassType.detect(from: "AAPL", apiType: "Common Stock") == .usStocks)
    }

    @Test func detectsFromApiTypeCrypto() {
        #expect(AssetClassType.detect(from: "DOGE", apiType: "crypto") == .crypto)
    }

    @Test func apiTypeOverridesTickerHeuristic() {
        // BTLG11 ends in "11" → ticker heuristic says FII; but if the
        // backend (somehow) tagged it "stock", the apiType wins. This
        // protects against future backend mapping changes leaking into
        // misclassification on the client.
        #expect(AssetClassType.detect(from: "BTLG11.SA", apiType: "stock") == .acoesBR)
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
