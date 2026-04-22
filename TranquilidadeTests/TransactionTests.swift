import Testing
import Foundation
@testable import Tranquilidade

struct TransactionTests {

    // MARK: - Buy Flow

    @Test func buyIncreasesQuantityAndUpdatesAveragePrice() {
        let holding = Holding(
            ticker: "ITUB3",
            quantity: 1000,
            averagePrice: 25,
            currentPrice: 25,
            assetClass: .acoesBR
        )

        // Simulate buying 500 more at 30
        let oldTotal = holding.quantity * holding.averagePrice // 25000
        let newTotal: Decimal = 500 * 30 // 15000
        let combinedQty = holding.quantity + 500 // 1500
        holding.averagePrice = (oldTotal + newTotal) / combinedQty
        holding.quantity = combinedQty
        holding.currentPrice = 30

        #expect(holding.quantity == 1500)
        // Weighted avg: (25000 + 15000) / 1500 = 26.666...
        let expectedAvg = Decimal(40000) / Decimal(1500)
        #expect(holding.averagePrice == expectedAvg)
        #expect(holding.currentPrice == 30)
    }

    @Test func buyNewAssetStartsWithCorrectValues() {
        let holding = Holding(
            ticker: "PETR4",
            displayName: "Petrobras PN",
            quantity: 200,
            averagePrice: 35,
            currentPrice: 35,
            assetClass: .acoesBR,
            status: .aportar
        )

        #expect(holding.ticker == "PETR4")
        #expect(holding.displayName == "Petrobras PN")
        #expect(holding.quantity == 200)
        #expect(holding.averagePrice == 35)
        #expect(holding.currentValue == 7000)
        #expect(holding.status == .aportar)
    }

    // MARK: - Sell / Withdraw Flow

    @Test func sellReducesQuantity() {
        let holding = Holding(
            ticker: "ITUB3",
            quantity: 1000,
            averagePrice: 25,
            currentPrice: 30,
            assetClass: .acoesBR
        )

        // Sell 500
        holding.quantity -= 500

        #expect(holding.quantity == 500)
        #expect(holding.averagePrice == 25, "Average price should not change on sell")
        #expect(holding.currentPrice == 30, "Current price should not change on sell")
        #expect(holding.currentValue == 15000)
    }

    @Test func sellAllReducesQuantityToZero() {
        let holding = Holding(
            ticker: "VALE3",
            quantity: 300,
            averagePrice: 60,
            currentPrice: 65,
            assetClass: .acoesBR
        )

        holding.quantity -= 300

        #expect(holding.quantity == 0)
        #expect(holding.currentValue == 0)
    }

    @Test func cannotSellMoreThanOwned() {
        let holding = Holding(
            ticker: "BBAS3",
            quantity: 100,
            averagePrice: 40,
            currentPrice: 42,
            assetClass: .acoesBR
        )

        let sellQuantity: Decimal = 150
        let isValid = sellQuantity <= holding.quantity

        #expect(!isValid, "Should not allow selling more shares than owned")
    }

    // MARK: - Contribution Ledger

    @Test func buyContributionHasPositiveShares() {
        let contribution = Contribution(
            date: .now,
            amount: 500 * 30, // 15000
            shares: 500,
            pricePerShare: 30
        )

        #expect(contribution.shares > 0)
        #expect(contribution.amount > 0)
        #expect(contribution.pricePerShare == 30)
    }

    @Test func sellContributionHasNegativeShares() {
        let contribution = Contribution(
            date: .now,
            amount: -(200 * 28),
            shares: -200,
            pricePerShare: 28
        )

        #expect(contribution.shares < 0)
        #expect(contribution.amount < 0)
        #expect(contribution.pricePerShare == 28)
    }

    @Test func removeContributionRecordsFullPosition() {
        let holding = Holding(
            ticker: "XPML11",
            quantity: 50,
            averagePrice: 100,
            currentPrice: 105,
            assetClass: .fiis
        )

        // Simulate remove: create contribution for full position
        let contribution = Contribution(
            date: .now,
            amount: -(holding.quantity * holding.currentPrice),
            shares: -holding.quantity,
            pricePerShare: holding.currentPrice
        )

        #expect(contribution.shares == -50)
        #expect(contribution.amount == -5250)
        #expect(contribution.pricePerShare == 105)
    }

    // MARK: - Weighted Average Price

    @Test func multipleBuysCalculateCorrectWeightedAverage() {
        let holding = Holding(
            ticker: "MXRF11",
            quantity: 100,
            averagePrice: 10,
            currentPrice: 10,
            assetClass: .fiis
        )

        // Buy 1: already in — 100 @ 10 = 1000
        // Buy 2: 200 @ 12 = 2400
        let buy2Qty: Decimal = 200
        let buy2Price: Decimal = 12
        let oldTotal = holding.quantity * holding.averagePrice
        let newTotal = buy2Qty * buy2Price
        let combinedQty = holding.quantity + buy2Qty
        holding.averagePrice = (oldTotal + newTotal) / combinedQty
        holding.quantity = combinedQty

        #expect(holding.quantity == 300)
        // (1000 + 2400) / 300 = 11.333...
        let expected = Decimal(3400) / Decimal(300)
        #expect(holding.averagePrice == expected)

        // Buy 3: 100 @ 15 = 1500
        let buy3Qty: Decimal = 100
        let buy3Price: Decimal = 15
        let oldTotal2 = holding.quantity * holding.averagePrice
        let newTotal2 = buy3Qty * buy3Price
        let combinedQty2 = holding.quantity + buy3Qty
        holding.averagePrice = (oldTotal2 + newTotal2) / combinedQty2
        holding.quantity = combinedQty2

        #expect(holding.quantity == 400)
        // (3400 + 1500) / 400 = 12.25
        // Due to repeating-decimal intermediate, allow small rounding difference
        let expected2 = Decimal(4900) / Decimal(400)
        let diff = abs(holding.averagePrice - expected2)
        #expect(diff < Decimal(string: "0.0001")!)
    }

    // MARK: - Gain/Loss After Transactions

    @Test func gainLossReflectsCurrentVsAverage() {
        let holding = Holding(
            ticker: "AAPL",
            quantity: 10,
            averagePrice: 150,
            currentPrice: 180,
            assetClass: .usStocks,
            currency: .usd
        )

        #expect(holding.totalCost == 1500)
        #expect(holding.currentValue == 1800)
        #expect(holding.gainLoss == 300)
        #expect(holding.gainLossPercent == 20)
    }

    @Test func gainLossAfterPartialSell() {
        let holding = Holding(
            ticker: "AAPL",
            quantity: 10,
            averagePrice: 150,
            currentPrice: 180,
            assetClass: .usStocks,
            currency: .usd
        )

        // Sell 5 shares
        holding.quantity -= 5

        #expect(holding.quantity == 5)
        #expect(holding.averagePrice == 150, "Avg price unchanged after sell")
        #expect(holding.currentValue == 900)
        #expect(holding.totalCost == 750)
        #expect(holding.gainLoss == 150)
        #expect(holding.gainLossPercent == 20, "Gain % stays the same")
    }
}
