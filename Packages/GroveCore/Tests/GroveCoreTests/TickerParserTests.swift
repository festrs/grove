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

    @Test func normalizedTickerStripsSASuffix() {
        #expect("ITUB3.SA".normalizedTicker == "ITUB3")
        #expect("BTLG11.SA".normalizedTicker == "BTLG11")
    }

    @Test func normalizedTickerUppercasesAndTrims() {
        #expect("  itub3  ".normalizedTicker == "ITUB3")
        #expect("itub3.sa".normalizedTicker == "ITUB3")
    }

    @Test func normalizedTickerLeavesUSAlone() {
        #expect("AAPL".normalizedTicker == "AAPL")
        #expect("BRK.B".normalizedTicker == "BRK.B")
    }

    @Test func normalizedTickerOnlyStripsTrailingSA() {
        // "PSA" must NOT become "P" — only the literal `.SA` suffix is stripped.
        #expect("PSA".normalizedTicker == "PSA")
        #expect("USA.SA".normalizedTicker == "USA")
    }
}

// MARK: - Holding init normalization

struct HoldingTickerNormalizationTests {

    @Test func holdingInitStripsSASuffix() {
        let h = Holding(ticker: "ITUB3.SA", assetClass: .acoesBR)
        #expect(h.ticker == "ITUB3")
    }

    @Test func holdingInitUppercases() {
        let h = Holding(ticker: "itub3", assetClass: .acoesBR)
        #expect(h.ticker == "ITUB3")
    }
}
