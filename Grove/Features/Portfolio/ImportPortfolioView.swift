import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportPortfolioView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @State private var viewModel = ImportViewModel()

    let portfolio: Portfolio

    var body: some View {
        NavigationStack {
            ImportView(
                viewModel: viewModel,
                showFileOption: true,
                existingTickers: existingTickers,
                confirmLabel: "Import"
            ) { positions in
                confirmImport(positions)
                dismiss()
            }
            .onAppear {
                viewModel.maxSelectable = Holding.remainingSlots(modelContext: modelContext)
            }
            .padding(.vertical, Theme.Spacing.md)
            .background(Color.tqBackground)
            .navigationTitle("Import Assets")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            #if os(macOS)
            .frame(minWidth: 600, minHeight: 500)
            #endif
        }
    }

    private var existingTickers: Set<String> {
        Set((portfolio.holdings ?? []).map { $0.ticker.uppercased() })
    }

    private func confirmImport(_ positions: [ImportedPosition]) {
        let service = backendService
        for position in positions {
            let assetClass = position.assetClassType
            let holding = Holding(
                ticker: position.ticker,
                displayName: position.displayName,
                currentPrice: Decimal(position.currentPrice),
                assetClass: assetClass,
                status: position.quantity > 0 ? .aportar : .estudo
            )
            holding.portfolio = portfolio
            modelContext.insert(holding)

            Task { try? await service.trackSymbol(symbol: position.ticker, assetClass: assetClass.rawValue) }

            if position.quantity > 0 {
                let pricePerShare = Decimal(position.currentPrice)
                let shares = Decimal(position.quantity)
                let contribution = Contribution(
                    date: .now,
                    amount: shares * pricePerShare,
                    shares: shares,
                    pricePerShare: pricePerShare
                )
                contribution.holding = holding
                modelContext.insert(contribution)
                holding.recalculateFromContributions()
            }
        }
    }
}

// MARK: - UTType Extension

extension UTType {
    static let xlsx = UTType(filenameExtension: "xlsx") ?? .data
    static let spreadsheet = UTType(tag: "xls", tagClass: .filenameExtension, conformingTo: nil) ?? .data
}
