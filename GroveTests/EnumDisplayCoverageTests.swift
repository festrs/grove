import Testing
import Foundation
import GroveDomain

/// Lightweight coverage for display + routing accessors on the domain enums
/// (`Currency`, `HoldingStatus`, `AssetClassType`). These props feed many UI
/// surfaces; bugs surface as wrong icons/colors/symbols rather than crashes,
/// so the smoke-test value is in *exercising every case*. Asserts shape, not
/// pixel-exact strings, so localization tweaks don't churn this file.

@MainActor
struct EnumDisplayCoverageTests {

    // MARK: - Currency

    @Test func currencyExposesUniqueSymbolPerCase() {
        let symbols = Currency.allCases.map(\.symbol)
        #expect(Set(symbols).count == Currency.allCases.count)
        #expect(Currency.brl.symbol == "R$")
        #expect(Currency.usd.symbol == "$")
    }

    @Test func currencyExposesUppercaseCode() {
        for c in Currency.allCases {
            #expect(c.code == c.rawValue.uppercased())
        }
    }

    @Test func currencyLocalePerCase() {
        #expect(Currency.brl.locale.identifier == "pt_BR")
        #expect(Currency.usd.locale.identifier == "en_US")
    }

    @Test func currencyDisplayNameMentionsSymbol() {
        for c in Currency.allCases {
            #expect(c.displayName.contains(c.symbol),
                    "displayName should embed the symbol so users connect them")
        }
    }

    @Test func currencyIdentifiableMatchesRawValue() {
        for c in Currency.allCases {
            #expect(c.id == c.rawValue)
        }
    }

    // MARK: - HoldingStatus

    @Test func holdingStatusDisplayNamePerCase() {
        #expect(HoldingStatus.estudo.displayName == "Study")
        #expect(HoldingStatus.aportar.displayName == "Invest")
        #expect(HoldingStatus.quarentena.displayName == "Quarantine")
        #expect(HoldingStatus.vender.displayName == "Sell")
    }

    @Test func holdingStatusIconPerCase() {
        // Each case must map to a distinct SF symbol so the UI can route
        // correctly. No exact-string assertion — just non-empty + unique.
        let icons = HoldingStatus.allCases.map(\.icon)
        for icon in icons { #expect(!icon.isEmpty) }
        #expect(Set(icons).count == HoldingStatus.allCases.count)
    }

    @Test func holdingStatusDescriptionPerCase() {
        for status in HoldingStatus.allCases {
            #expect(!status.description.isEmpty,
                    "Each status needs a human-readable hint for the picker")
        }
    }

    @Test func holdingStatusColorIsExercisedForEveryCase() {
        // SwiftUI Color isn't trivially comparable; asserting we can read the
        // accessor for every case at least guarantees no missing-case crash.
        for status in HoldingStatus.allCases {
            _ = status.color
        }
    }

    @Test func holdingStatusIdentifiableMatchesRawValue() {
        for status in HoldingStatus.allCases {
            #expect(status.id == status.rawValue)
        }
    }

    // MARK: - AssetClassType — display

    @Test func assetClassDisplayNameUniquePerCase() {
        let names = AssetClassType.allCases.map(\.displayName)
        for name in names { #expect(!name.isEmpty) }
        #expect(Set(names).count == AssetClassType.allCases.count)
    }

    @Test func assetClassShortNameUniquePerCase() {
        let names = AssetClassType.allCases.map(\.shortName)
        for name in names { #expect(!name.isEmpty) }
        #expect(Set(names).count == AssetClassType.allCases.count)
    }

    @Test func assetClassIconUniquePerCase() {
        let icons = AssetClassType.allCases.map(\.icon)
        for icon in icons { #expect(!icon.isEmpty) }
        #expect(Set(icons).count == AssetClassType.allCases.count)
    }

    @Test func assetClassColorIsExercisedForEveryCase() {
        for cls in AssetClassType.allCases {
            _ = cls.color
        }
    }

    @Test func assetClassIdentifiableMatchesRawValue() {
        for cls in AssetClassType.allCases {
            #expect(cls.id == cls.rawValue)
        }
    }

    // MARK: - AssetClassType — routing (currency + tax)

    @Test func assetClassDefaultCurrencyCoversAllCases() {
        // Already-tested cases revisited so the test is self-contained, plus
        // crypto's USD pricing which the existing suite skips.
        #expect(AssetClassType.acoesBR.defaultCurrency == .brl)
        #expect(AssetClassType.fiis.defaultCurrency == .brl)
        #expect(AssetClassType.rendaFixa.defaultCurrency == .brl)
        #expect(AssetClassType.usStocks.defaultCurrency == .usd)
        #expect(AssetClassType.reits.defaultCurrency == .usd)
        #expect(AssetClassType.crypto.defaultCurrency == .usd)
    }

    @Test func assetClassDefaultTaxTreatmentCoversAllCases() {
        #expect(AssetClassType.acoesBR.defaultTaxTreatment == .exempt)
        #expect(AssetClassType.fiis.defaultTaxTreatment == .exempt)
        #expect(AssetClassType.usStocks.defaultTaxTreatment == .nra30)
        #expect(AssetClassType.reits.defaultTaxTreatment == .nra30)
        #expect(AssetClassType.crypto.defaultTaxTreatment == .crypto15)
        #expect(AssetClassType.rendaFixa.defaultTaxTreatment == .irRegressivo)
    }

    // MARK: - AssetClassType — capability flags

    @Test func dividendCapabilityMatchesRealWorldClasses() {
        // Equity-like classes pay dividends; crypto/RF do not. UI uses this
        // to hide the dividend tab and skip backend dividend pulls.
        #expect(AssetClassType.acoesBR.hasDividends)
        #expect(AssetClassType.fiis.hasDividends)
        #expect(AssetClassType.usStocks.hasDividends)
        #expect(AssetClassType.reits.hasDividends)
        #expect(!AssetClassType.crypto.hasDividends)
        #expect(!AssetClassType.rendaFixa.hasDividends)
    }

    @Test func priceHistoryCapabilityMatchesTradableClasses() {
        // Renda Fixa is the lone exception — fixed-income certificates have
        // no continuous market price, so the chart is hidden in UI.
        #expect(AssetClassType.acoesBR.hasPriceHistory)
        #expect(AssetClassType.fiis.hasPriceHistory)
        #expect(AssetClassType.usStocks.hasPriceHistory)
        #expect(AssetClassType.reits.hasPriceHistory)
        #expect(AssetClassType.crypto.hasPriceHistory)
        #expect(!AssetClassType.rendaFixa.hasPriceHistory)
    }

    @Test func fundamentalsCapabilityLimitedToEquities() {
        // Backend only ships fundamentals for individual companies — FIIs,
        // REITs, crypto, RF have no P/E or revenue equivalents.
        #expect(AssetClassType.acoesBR.hasFundamentals)
        #expect(AssetClassType.usStocks.hasFundamentals)
        #expect(!AssetClassType.fiis.hasFundamentals)
        #expect(!AssetClassType.reits.hasFundamentals)
        #expect(!AssetClassType.crypto.hasFundamentals)
        #expect(!AssetClassType.rendaFixa.hasFundamentals)
    }

    // MARK: - AssetClassType — extra detect paths

    @Test func detectFallsBackForBrazilianTickersEndingInFiveOrSix() {
        // PIBB11 and a hypothetical "5" / "6" suffix shouldn't crash; the
        // 3/4/5/6 suffix branch returns acoesBR for non-FII Brazilian codes.
        #expect(AssetClassType.detect(from: "BTOW6") == .acoesBR)
        #expect(AssetClassType.detect(from: "BBSE5") == .acoesBR)
    }

    @Test func detectReturnsNilForUnclassifiable() {
        // Long all-letter strings don't match the US-stock heuristic
        // (max 5 chars), and have no numeric suffix → nil.
        #expect(AssetClassType.detect(from: "GIGANTICTICKER") == nil)
    }

    @Test func detectStripsExchangeSuffix() {
        // ".SA" stripping must run for both ticker heuristic and apiType
        // paths so search results from B3 keep classifying correctly.
        #expect(AssetClassType.detect(from: "ITUB3.SA") == .acoesBR)
        #expect(AssetClassType.detect(from: "KNRI11.SA") == .fiis)
    }
}
