import SwiftUI
import SwiftData
import GroveDomain

/// Sheet shown after selecting a search result from the portfolio search bar.
/// Collects quantity, price, and asset class to add the holding.
struct AddAssetDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AddAssetViewModel

    init(searchResult: StockSearchResultDTO) {
        _viewModel = State(initialValue: AddAssetViewModel(searchResult: searchResult))
    }

    var body: some View {
        NavigationStack {
            Form {
                assetHeaderSection
                assetClassSection
                purchaseDetailsSection
                if viewModel.totalValue > 0 { totalSection }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Add Asset")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if viewModel.addAsset(modelContext: modelContext, backendService: backendService) {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid)
                }
            }
            .task { await viewModel.fetchPrice(backendService: backendService) }
        }
        #if os(macOS)
        .frame(minWidth: 500, idealWidth: 560, minHeight: 420)
        #endif
    }

    private var assetHeaderSection: some View {
        Section {
            HStack {
                Circle()
                    .fill(viewModel.detectedClass.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: viewModel.detectedClass.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(viewModel.detectedClass.color)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.searchResult.symbol)
                        .font(.title3).fontWeight(.bold)
                    if let name = viewModel.searchResult.name {
                        Text(name)
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var assetClassSection: some View {
        Section("Asset Class") {
            Picker("Class", selection: $viewModel.detectedClass) {
                ForEach(AssetClassType.allCases) { ct in
                    HStack {
                        Image(systemName: ct.icon)
                        Text(ct.displayName)
                    }
                    .tag(ct)
                }
            }
        }
    }

    private var purchaseDetailsSection: some View {
        Section("Purchase Details") {
            LabeledContent("Quantity") {
                TextField("0", text: $viewModel.quantityText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Price (\(viewModel.currency.symbol))") {
                if viewModel.isFetchingPrice {
                    ProgressView()
                } else {
                    TextField("0,00", text: $viewModel.priceText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                }
            }

            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
        }
    }

    private var totalSection: some View {
        Section {
            HStack {
                Text("Total").fontWeight(.semibold)
                Spacer()
                Text(viewModel.totalValue.formatted(as: viewModel.currency))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.tqAccentGreen)
            }
        }
    }
}

#Preview {
    AddAssetDetailSheet(searchResult: StockSearchResultDTO(id: "ITUB3.SA", symbol: "ITUB3.SA", name: "ITAU UNIBANCO HOLDING S.A.", type: "stock", price: "46.37", currency: "BRL", change: "-0.92", sector: "Finance", logo: nil))
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self], inMemory: true)
}
