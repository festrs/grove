import SwiftUI
import SwiftData
import GroveDomain

struct AddHoldingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddHoldingViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Search Asset") {
                    TextField("Ticker (e.g.: ITUB3, AAPL)", text: $viewModel.searchQuery)
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .autocorrectionDisabled()
                        .onChange(of: viewModel.searchQuery) { _, query in
                            Task {
                                await viewModel.search(query: query, service: backendService)
                            }
                        }

                    if viewModel.isSearching {
                        HStack {
                            ProgressView()
                            Text("Searching...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(viewModel.searchResults) { result in
                        Button {
                            viewModel.selectSearchResult(result, service: backendService)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(result.symbol)
                                        .fontWeight(.semibold)
                                    if let name = result.name {
                                        Text(name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if let type = result.type {
                                    Text(type)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                if !viewModel.ticker.isEmpty {
                    Section("Details") {
                        LabeledContent("Ticker", value: viewModel.ticker)

                        if viewModel.currentPrice > 0 {
                            LabeledContent("Current Price", value: Money(amount: viewModel.currentPrice, currency: viewModel.assetClass.defaultCurrency).formatted())
                        }

                        HStack {
                            Text("Quantity")
                            Spacer()
                            TextField("0", text: $viewModel.quantityText)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }

                        Picker("Class", selection: $viewModel.assetClass) {
                            ForEach(AssetClassType.allCases) { classType in
                                Label(classType.displayName, systemImage: classType.icon)
                                    .tag(classType)
                            }
                        }

                        Picker("Status", selection: $viewModel.status) {
                            ForEach(HoldingStatus.allCases) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                    }
                }

                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
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
                        if viewModel.save(modelContext: modelContext, backendService: backendService) {
                            dismiss()
                        }
                    }
                    .disabled(viewModel.ticker.isEmpty || viewModel.quantityText.isEmpty)
                }
            }
        }
    }
}
