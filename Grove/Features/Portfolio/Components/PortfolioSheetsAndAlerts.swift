import SwiftUI
import SwiftData
import GroveDomain

/// Shared sheet + alert wiring for the portfolio screens. Both
/// `CompactPortfolioView` and `WidePortfolioView` attach this so the buy/sell
/// transaction sheets, the import sheet, the edit/new portfolio sheets, and
/// the remove-asset confirmation all behave identically across platforms.
struct PortfolioSheetsAndAlerts: ViewModifier {
    @Bindable var viewModel: PortfolioViewModel
    @Binding var holdingToBuy: Holding?
    @Binding var holdingToSell: Holding?
    @Binding var showingImport: Bool
    @Binding var recentlyAdded: [StockSearchResultDTO]
    let holdings: [Holding]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showingAddDetails, onDismiss: {
                if let result = viewModel.selectedSearchResult {
                    let wasAdded = holdings.contains { $0.ticker == result.symbol }
                    if wasAdded && !recentlyAdded.contains(where: { $0.symbol == result.symbol }) {
                        withAnimation { recentlyAdded.insert(result, at: 0) }
                    }
                    viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
                }
            }) {
                if let result = viewModel.selectedSearchResult {
                    AddAssetDetailSheet(searchResult: result)
                }
            }
            .sheet(isPresented: $viewModel.showingEditPortfolio) {
                if let portfolio = viewModel.selectedPortfolio {
                    EditPortfolioView(portfolio: portfolio)
                }
            }
            .sheet(isPresented: $viewModel.showingNewPortfolio) {
                NewPortfolioSheet { name in
                    viewModel.createPortfolio(name: name, modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
                }
            }
            .sheet(item: $holdingToBuy, onDismiss: { viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }) { holding in
                NewTransactionView(transactionType: .buy, preselectedHolding: holding)
            }
            .sheet(item: $holdingToSell, onDismiss: { viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }) { holding in
                NewTransactionView(transactionType: .sell, preselectedHolding: holding)
            }
            .sheet(isPresented: $showingImport, onDismiss: { viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }) {
                if let portfolio = viewModel.selectedPortfolio {
                    ImportPortfolioView(portfolio: portfolio)
                }
            }
            .alert(
                "Remove Asset",
                isPresented: Binding(
                    get: { viewModel.holdingToRemove != nil },
                    set: { if !$0 { viewModel.holdingToRemove = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) { viewModel.holdingToRemove = nil }
                Button("Remove", role: .destructive) {
                    if let h = viewModel.holdingToRemove {
                        viewModel.deleteHolding(h, modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
                        viewModel.holdingToRemove = nil
                    }
                }
            } message: {
                if let h = viewModel.holdingToRemove {
                    if h.contributions.isEmpty {
                        Text("Remove \(h.ticker) from portfolio?")
                    } else {
                        Text("Remove \(h.ticker) from portfolio? All \(h.contributions.count) transaction(s) will also be deleted. This action cannot be undone.")
                    }
                }
            }
    }
}
