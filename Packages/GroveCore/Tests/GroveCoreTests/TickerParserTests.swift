import Testing
import GroveDomain

struct TickerParserTests {

    @Test func parseTickersFromLines() {
        let result = TickerParser.parse("ITUB3\nPETR4\nBTLG11")
        #expect(result == ["ITUB3", "PETR4", "BTLG11"])
    }

    @Test func parseTickersWithComma() {
        let result = TickerParser.parse("ITUB3, 100\nPETR4, 200")
        #expect(result == ["ITUB3", "PETR4"])
    }

    @Test func parseTickersWithSemicolon() {
        let result = TickerParser.parse("ITUB3;100")
        #expect(result == ["ITUB3"])
    }

    @Test func parseTickersWithTab() {
        let result = TickerParser.parse("ITUB3\t100")
        #expect(result == ["ITUB3"])
    }

    @Test func parseTickersSkipsEmptyLines() {
        let result = TickerParser.parse("\n\nITUB3\n\n")
        #expect(result == ["ITUB3"])
    }

    @Test func parseTickersSkipsNonTickers() {
        let result = TickerParser.parse("12345\nITUB3\n!!!")
        #expect(result == ["ITUB3"])
    }

    // MARK: - normalizedTicker
    //
    // The `.SA` suffix is owned by the backend (BR / FII responses always carry
    // it). iOS preserves whatever the backend sent — `normalizedTicker` is just
    // uppercase + trim so casing/whitespace from manual input doesn't leak in.

    @Test func normalizedTickerPreservesSASuffix() {
        #expect("ITUB3.SA".normalizedTicker == "ITUB3.SA")
        #expect("BTLG11.SA".normalizedTicker == "BTLG11.SA")
    }

    @Test func normalizedTickerUppercasesAndTrims() {
        #expect("  itub3.sa  ".normalizedTicker == "ITUB3.SA")
        #expect("itub3".normalizedTicker == "ITUB3")
        #expect("aapl".normalizedTicker == "AAPL")
    }

    @Test func normalizedTickerLeavesUSAlone() {
        #expect("AAPL".normalizedTicker == "AAPL")
        #expect("BRK.B".normalizedTicker == "BRK.B")
    }

    // MARK: - displayTicker

    @Test func displayTickerStripsSA() {
        #expect("ITUB3.SA".displayTicker == "ITUB3")
        #expect("BTLG11.SA".displayTicker == "BTLG11")
    }

    @Test func displayTickerLeavesNonSAAlone() {
        #expect("AAPL".displayTicker == "AAPL")
        #expect("BRK.B".displayTicker == "BRK.B")
        #expect("ITUB3".displayTicker == "ITUB3") // legacy bare BR — no SA to strip
    }
}

// MARK: - Holding init

struct HoldingTickerNormalizationTests {

    @Test func holdingInitPreservesSASuffix() {
        let h = Holding(ticker: "ITUB3.SA", assetClass: .acoesBR)
        #expect(h.ticker == "ITUB3.SA")
        #expect(h.displayTicker == "ITUB3")
    }

    @Test func holdingInitUppercases() {
        let h = Holding(ticker: "itub3.sa", assetClass: .acoesBR)
        #expect(h.ticker == "ITUB3.SA")
    }

    @Test func holdingInitLeavesUSAlone() {
        let h = Holding(ticker: "aapl", assetClass: .usStocks)
        #expect(h.ticker == "AAPL")
        #expect(h.displayTicker == "AAPL")
    }
}
