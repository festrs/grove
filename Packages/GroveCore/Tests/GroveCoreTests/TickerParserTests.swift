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
}
