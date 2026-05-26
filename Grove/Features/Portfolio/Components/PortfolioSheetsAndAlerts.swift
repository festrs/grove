import SwiftUI
import SwiftData
import GroveDomain

/// Shared sheet + alert wiring for the portfolio root screens. Hosts the
/// edit-portfolio sheet, the import sheet, and the remove-asset
/// confirmation. The add-ticker flow lives inside `AssetClassHoldingsView`
/// (scoped to the chosen class); per-class buy/sell sheets do too.
struct PortfolioSheetsAndAlerts: ViewModifier {
    @Bindable var viewModel: PortfolioViewModel
    @Binding var showingImport: Bool
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
