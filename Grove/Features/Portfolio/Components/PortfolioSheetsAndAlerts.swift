import SwiftUI
import SwiftData
import GroveDomain

/// Shared sheet + alert wiring for the portfolio root screens. Hosts the
/// edit-portfolio sheet, the import sheet, the global add-ticker flow, and
/// the remove-asset confirmation. Per-class buy/sell sheets still live
/// inside `AssetClassHoldingsView`.
struct PortfolioSheetsAndAlerts: ViewModifier {
    @Bindable var viewModel: PortfolioViewModel
    @Binding var showingImport: Bool
    @Binding var showingAddTicker: Bool
    @Binding var pendingAdd: AddTickerSelection?
    let holdings: [Holding]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayCurrency) private var displayCurrency
    @Environment(\.rates) private var rates

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showingEditPortfolio) {
                if let portfolio = viewModel.portfolio {
                    EditPortfolioView(portfolio: portfolio)
                }
            }
            .sheet(isPresented: $showingImport, onDismiss: { viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates) }) {
                if let portfolio = viewModel.portfolio {
                    ImportPortfolioView(portfolio: portfolio)
                }
            }
            .sheet(isPresented: $showingAddTicker) {
                AddTickerSheet { selection in
                    pendingAdd = selection
                }
            }
            .sheet(item: $pendingAdd, onDismiss: {
                viewModel.loadData(modelContext: modelContext, displayCurrency: displayCurrency, rates: rates)
            }) { selection in
                switch selection {
                case .found(let result):
                    AddAssetDetailSheet(searchResult: result, assetClass: nil)
                case .custom(let symbol):
                    AddAssetDetailSheet(customSymbol: symbol)
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
                    if h.transactions.isEmpty {
                        Text("Remove \(h.ticker) from portfolio?")
                    } else {
                        Text("Remove \(h.ticker) from portfolio? All \(h.transactions.count) transaction(s) will also be deleted. This action cannot be undone.")
                    }
                }
            }
    }
}
