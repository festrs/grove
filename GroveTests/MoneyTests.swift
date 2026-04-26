import Testing
import Foundation
@testable import Grove

struct MoneyTests {

    // MARK: - Construction

    @Test func zeroProducesZeroAmount() {
        let m = Money.zero(in: .brl)
        #expect(m.amount == 0)
        #expect(m.currency == .brl)
    }

    // MARK: - Addition / subtraction

    @Test func additionSameCurrency() {
        let a = Money(amount: 100, currency: .brl)
        let b = Money(amount: 50, currency: .brl)
        let result = a + b
        #expect(result.amount == 150)
        #expect(result.currency == .brl)
    }

    @Test func subtractionSameCurrency() {
        let a = Money(amount: 100, currency: .usd)
        let b = Money(amount: 30, currency: .usd)
        let result = a - b
        #expect(result.amount == 70)
        #expect(result.currency == .usd)
    }

    // MARK: - Multiplication / division by Decimal

    @Test func multiplyByDecimal() {
        let m = Money(amount: 50, currency: .brl)
        let result = m * Decimal(3)
        #expect(result.amount == 150)
        #expect(result.currency == .brl)
    }

    @Test func divideByDecimal() {
        let m = Money(amount: 100, currency: .brl)
        let result = m / Decimal(4)
        #expect(result.amount == 25)
        #expect(result.currency == .brl)
    }

    @Test func unaryMinus() {
        let m = Money(amount: 42, currency: .brl)
        let neg = -m
        #expect(neg.amount == -42)
        #expect(neg.currency == .brl)
    }

    // MARK: - Conversion

    @Test func conversionSameCurrencyIsIdentity() {
        let rates = StaticRates(brlPerUsd: 5)
        let m = Money(amount: 100, currency: .brl)
        let converted = m.converted(to: .brl, using: rates)
        #expect(converted == m)
    }

    @Test func conversionUsdToBrl() {
        let rates = StaticRates(brlPerUsd: 5)
        let m = Money(amount: 100, currency: .usd)
        let converted = m.converted(to: .brl, using: rates)
        #expect(converted.amount == 500)
        #expect(converted.currency == .brl)
    }

    @Test func conversionRoundTripUsdBrlUsd() {
        let rates = StaticRates(brlPerUsd: 5)
        let original = Money(amount: 100, currency: .usd)
        let toBrl = original.converted(to: .brl, using: rates)
        let backToUsd = toBrl.converted(to: .usd, using: rates)
        #expect(backToUsd.amount == 100)
        #expect(backToUsd.currency == .usd)
    }

    // MARK: - Sum mixed-currency

    @Test func sumMixedCurrencies() {
        let rates = StaticRates(brlPerUsd: 5)
        let items = [
            Money(amount: 100, currency: .brl),
            Money(amount: 20, currency: .usd),
        ]
        let total = items.sum(in: .brl, using: rates)
        #expect(total.amount == 200)
        #expect(total.currency == .brl)
    }

    // MARK: - Formatting

    @Test func formattedNativeBRL() {
        let m = Money(amount: 1234.56, currency: .brl)
        let s = m.formatted()
        #expect(s.contains("R$"))
    }

    @Test func formattedNativeUSD() {
        let m = Money(amount: 99.99, currency: .usd)
        let s = m.formatted()
        #expect(s.contains("$"))
    }

    @Test func formattedInOtherCurrency() {
        let rates = StaticRates(brlPerUsd: 5)
        let m = Money(amount: 100, currency: .brl)
        let s = m.formatted(in: .usd, using: rates)
        #expect(s.contains("$"))
    }

    // MARK: - DTO

    @Test func dtoRoundTrip() {
        let m = Money(amount: Decimal(string: "1234.56")!, currency: .usd)
        let dto = m.dto
        #expect(dto.currency == "USD")

        let parsed = Money(dto: dto)
        #expect(parsed != nil)
        #expect(parsed!.amount == m.amount)
        #expect(parsed!.currency == .usd)
    }

    @Test func dtoFailsOnInvalidCurrency() {
        let dto = MoneyDTO(amount: "10", currency: "ZZZ")
        #expect(Money(dto: dto) == nil)
    }

    @Test func dtoFailsOnInvalidAmount() {
        let dto = MoneyDTO(amount: "not-a-number", currency: "BRL")
        #expect(Money(dto: dto) == nil)
    }

    // MARK: - Comparable

    @Test func comparableSameCurrency() {
        let a = Money(amount: 50, currency: .brl)
        let b = Money(amount: 100, currency: .brl)
        #expect(a < b)
        #expect(b > a)
    }
}
