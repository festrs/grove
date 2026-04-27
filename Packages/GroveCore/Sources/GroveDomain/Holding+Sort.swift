import Foundation

extension Sequence where Element == Holding {
    /// Order holdings by allocation gap (under-target first). Used by the
    /// portfolio list to surface positions that most need a buy.
    public func sortedByAllocationGap(
        totalValue: Money,
        in displayCurrency: Currency,
        rates: any ExchangeRates
    ) -> [Holding] {
        sorted { a, b in
            let gapA = a.allocationGap(totalValue: totalValue, in: displayCurrency, rates: rates)
            let gapB = b.allocationGap(totalValue: totalValue, in: displayCurrency, rates: rates)
            return gapA > gapB
        }
    }
}
