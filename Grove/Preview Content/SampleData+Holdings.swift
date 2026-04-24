import Foundation

extension Holding {
    // MARK: - Acoes BR
    static var itub3: Holding {
        Holding(ticker: "ITUB3", displayName: "Itau Unibanco ON", quantity: 556, averagePrice: 28.50, currentPrice: 32.50, dividendYield: 6.5, assetClass: .acoesBR, status: .aportar, targetPercent: 8)
    }
    static var wege3: Holding {
        Holding(ticker: "WEGE3", displayName: "WEG ON", quantity: 200, averagePrice: 35.00, currentPrice: 42.00, dividendYield: 1.2, assetClass: .acoesBR, status: .quarentena, targetPercent: 5)
    }
    static var petr4: Holding {
        Holding(ticker: "PETR4", displayName: "Petrobras PN", quantity: 300, averagePrice: 28.00, currentPrice: 36.80, dividendYield: 12.0, assetClass: .acoesBR, status: .aportar, targetPercent: 7)
    }
    static var taee11: Holding {
        Holding(ticker: "TAEE11", displayName: "Taesa Unit", quantity: 150, averagePrice: 34.00, currentPrice: 38.50, dividendYield: 9.0, assetClass: .acoesBR, status: .quarentena, targetPercent: 4)
    }
    static var lren3: Holding {
        Holding(ticker: "LREN3", displayName: "Lojas Renner ON", quantity: 100, averagePrice: 22.00, currentPrice: 16.50, dividendYield: 2.5, assetClass: .acoesBR, status: .vender, targetPercent: 3)
    }

    // MARK: - FIIs
    static var xpml11: Holding {
        Holding(ticker: "XPML11", displayName: "XP Malls FII", quantity: 120, averagePrice: 92.00, currentPrice: 98.00, dividendYield: 8.2, assetClass: .fiis, status: .aportar, targetPercent: 5)
    }
    static var btlg11: Holding {
        Holding(ticker: "BTLG11", displayName: "BTG Logistica FII", quantity: 80, averagePrice: 95.00, currentPrice: 102.00, dividendYield: 7.8, assetClass: .fiis, status: .aportar, targetPercent: 4)
    }
    static var knri11: Holding {
        Holding(ticker: "KNRI11", displayName: "Kinea Renda Imobiliaria", quantity: 60, averagePrice: 130.00, currentPrice: 142.00, dividendYield: 7.5, assetClass: .fiis, status: .aportar, targetPercent: 3)
    }
    static var mxrf11: Holding {
        Holding(ticker: "MXRF11", displayName: "Maxi Renda FII", quantity: 500, averagePrice: 10.20, currentPrice: 10.50, dividendYield: 11.0, assetClass: .fiis, status: .quarentena, targetPercent: 3)
    }

    // MARK: - US Stocks
    static var aapl: Holding {
        Holding(ticker: "AAPL", displayName: "Apple Inc", quantity: 50, averagePrice: 150, currentPrice: 180, dividendYield: 0.5, assetClass: .usStocks, currency: .usd, status: .aportar, targetPercent: 8)
    }
    static var nvda: Holding {
        Holding(ticker: "NVDA", displayName: "NVIDIA Corp", quantity: 30, averagePrice: 200, currentPrice: 880, dividendYield: 0.03, assetClass: .usStocks, currency: .usd, status: .quarentena, targetPercent: 6)
    }
    static var goog: Holding {
        Holding(ticker: "GOOG", displayName: "Alphabet Inc", quantity: 20, averagePrice: 120, currentPrice: 175, dividendYield: 0.5, assetClass: .usStocks, currency: .usd, status: .aportar, targetPercent: 6)
    }
    static var vti: Holding {
        Holding(ticker: "VTI", displayName: "Vanguard Total Stock", quantity: 40, averagePrice: 210, currentPrice: 260, dividendYield: 1.3, assetClass: .usStocks, currency: .usd, status: .aportar, targetPercent: 8)
    }

    // MARK: - REITs
    static var o: Holding {
        Holding(ticker: "O", displayName: "Realty Income Corp", quantity: 100, averagePrice: 55, currentPrice: 58, dividendYield: 5.5, assetClass: .reits, currency: .usd, status: .aportar, targetPercent: 5)
    }
    static var dlr: Holding {
        Holding(ticker: "DLR", displayName: "Digital Realty Trust", quantity: 30, averagePrice: 100, currentPrice: 145, dividendYield: 3.4, assetClass: .reits, currency: .usd, status: .aportar, targetPercent: 5)
    }

    // MARK: - Crypto
    static var btc: Holding {
        Holding(ticker: "BTC", displayName: "Bitcoin", quantity: 0.5, averagePrice: 40_000, currentPrice: 67_000, dividendYield: 0, assetClass: .crypto, currency: .usd, status: .aportar, targetPercent: 5)
    }

    // MARK: - Renda Fixa
    static var ipca2035: Holding {
        Holding(ticker: "IPCA+6", displayName: "Tesouro IPCA+ 2035", quantity: 2, averagePrice: 3200, currentPrice: 3450, dividendYield: 6, assetClass: .rendaFixa, status: .aportar, targetPercent: 5)
    }

    // MARK: - All samples
    static var allSamples: [Holding] {
        [.itub3, .wege3, .petr4, .taee11, .lren3,
         .xpml11, .btlg11, .knri11, .mxrf11,
         .aapl, .nvda, .goog, .vti,
         .o, .dlr,
         .btc,
         .ipca2035]
    }
}
