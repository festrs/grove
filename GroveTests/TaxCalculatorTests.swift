import Testing
import Foundation
@testable import Grove

struct TaxCalculatorTests {

    // MARK: - Net Multipliers

    @Test func fiiDividendsAreExempt() {
        let multiplier = TaxCalculator.netMultiplier(for: .fiis)
        #expect(multiplier == 1.0, "FII dividends should be 100% exempt")
    }

    @Test func brStockDividendsAreExempt() {
        let multiplier = TaxCalculator.netMultiplier(for: .acoesBR)
        #expect(multiplier == 1.0, "BR stock dividends are currently exempt")
    }

    @Test func usStocksHave30PercentWithholding() {
        let multiplier = TaxCalculator.netMultiplier(for: .usStocks)
        #expect(multiplier == 0.70, "US stocks should have 30% NRA withholding")
    }

    @Test func reitsHave30PercentWithholding() {
        let multiplier = TaxCalculator.netMultiplier(for: .reits)
        #expect(multiplier == 0.70, "REITs should have 30% NRA withholding")
    }

    @Test func cryptoHas15PercentTax() {
        let multiplier = TaxCalculator.netMultiplier(for: .crypto)
        #expect(multiplier == 0.85, "Crypto should have 15% tax rate")
    }

    @Test func rendaFixaHasRegressiveRate() {
        let multiplier = TaxCalculator.netMultiplier(for: .rendaFixa)
        #expect(multiplier == 0.80, "Renda fixa should have ~20% average rate")
    }

    // MARK: - Net Income Calculation

    @Test func netIncomeForExemptAsset() {
        let net = TaxCalculator.netIncome(gross: 1000, assetClass: .fiis)
        #expect(net == 1000, "Exempt assets should have net == gross")
    }

    @Test func netIncomeForUSStock() {
        let net = TaxCalculator.netIncome(gross: 1000, assetClass: .usStocks)
        #expect(net == 700, "US stock net should be 70% of gross")
    }

    @Test func withholdingTaxForUSStock() {
        let tax = TaxCalculator.withholdingTax(gross: 1000, assetClass: .usStocks)
        #expect(tax == 300, "US stock withholding should be 30%")
    }

    @Test func withholdingTaxForExemptIsZero() {
        let tax = TaxCalculator.withholdingTax(gross: 1000, assetClass: .fiis)
        #expect(tax == 0, "FII withholding should be zero")
    }

    // MARK: - Tax Breakdown

    @Test func breakdownAggregatesCorrectly() {
        let grossByClass: [AssetClassType: Decimal] = [
            .fiis: 1000,
            .usStocks: 500,
            .acoesBR: 200,
        ]
        let result = TaxCalculator.taxBreakdown(grossByClass: grossByClass)

        #expect(result.totalGross == 1700)
        #expect(result.totalTax == 150) // Only US stocks: 500 × 0.30 = 150
        #expect(result.totalNet == 1550)
        #expect(result.details.count == 3)
    }

    @Test func breakdownHandlesEmptyInput() {
        let result = TaxCalculator.taxBreakdown(grossByClass: [:])
        #expect(result.totalGross == 0)
        #expect(result.totalTax == 0)
        #expect(result.totalNet == 0)
        #expect(result.details.isEmpty)
    }
}
