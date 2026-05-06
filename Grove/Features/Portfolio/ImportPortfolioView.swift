import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import GroveDomain

struct ImportPortfolioView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @State private var importVM = ImportViewModel()
    @State private var confirmVM = ImportPortfolioViewModel()

    let portfolio: Portfolio

    var body: some View {
        NavigationStack {
            ImportView(
                viewModel: importVM,
                existingTickers: existingTickers,
                confirmLabel: "Import"
            ) { positions in
                confirmVM.confirmImport(
                    positions: positions,
                    portfolio: portfolio,
                    modelContext: modelContext,
                    backendService: backendService
                )
                dismiss()
            }
            .onAppear {
                importVM.maxSelectable = Holding.remainingSlots(modelContext: modelContext)
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
}

// MARK: - UTType Extension

extension UTType {
    static let xlsx = UTType(filenameExtension: "xlsx") ?? .data
    static let spreadsheet = UTType(tag: "xls", tagClass: .filenameExtension, conformingTo: nil) ?? .data
}
