import Foundation
import SwiftData
import GroveDomain
import GroveServices
import GroveRepositories

@Observable
@MainActor
final class IncomeHistoryViewModel {
    /// Day / Week / Month / Year summaries shown side-by-side at the top of
    /// the view. Each carries paid + projected so the UI can split them.
    var summaries: [IncomeWindowSummary] = []
    /// Per-asset-class breakdown for the user-selected window.
    var byClass: [PassiveIncomeByClass] = []
    /// Tax breakdown applied to `byClass.gross` (= paid + projected) for the
    /// selected window. Drives the per-class card's net/IR display.
    var taxBreakdown: MoneyTaxBreakdown?
    var selectedWindow: IncomeWindow = .year
    var isLoading = false

    private static let displayedWindows: [IncomeWindow] = [.day, .week, .month, .year]

    func loadData(modelContext: ModelContext, displayCurrency: Currency, rates: any ExchangeRates) {
        isLoading = true
        defer { isLoading = false }

        do {
            let holdings = try HoldingRepository(modelContext: modelContext).fetchAll()

            summaries = Self.displayedWindows.map { window in
                IncomeAggregator.summary(
                    holdings: holdings, window: window,
                    in: displayCurrency, rates: rates
                )
            }

            byClass = IncomeAggregator.byClass(
                holdings: holdings, window: selectedWindow,
                in: displayCurrency, rates: rates
            )

            // Tax breakdown over the selected-window gross (paid + projected).
            let grossByClass = Dictionary(
                uniqueKeysWithValues: byClass.map { ($0.assetClass, $0.total) }
            )
            taxBreakdown = TaxCalculator.taxBreakdown(
                grossByClass: grossByClass,
                displayCurrency: displayCurrency,
                rates: rates
            )
        } catch {
            summaries = []
            byClass = []
            taxBreakdown = nil
        }
    }

    func selectWindow(_ window: IncomeWindow,
                      modelContext: ModelContext,
                      displayCurrency: Currency,
                      rates: any ExchangeRates) {
        selectedWindow = window
        loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
    }
}
