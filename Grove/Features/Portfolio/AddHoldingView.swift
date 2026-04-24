import SwiftUI
import SwiftData

struct AddHoldingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddHoldingViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Buscar ativo") {
                    TextField("Ticker (ex: ITUB3, AAPL)", text: $viewModel.searchQuery)
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
                            Text("Buscando...")
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
                    Section("Detalhes") {
                        LabeledContent("Ticker", value: viewModel.ticker)

                        if viewModel.currentPrice > 0 {
                            LabeledContent("Preco atual", value: viewModel.currentPrice.formattedBRL())
                        }

                        HStack {
                            Text("Quantidade")
                            Spacer()
                            TextField("0", text: $viewModel.quantityText)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }

                        Picker("Classe", selection: $viewModel.assetClass) {
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
            .navigationTitle("Adicionar ativo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Adicionar") {
                        if viewModel.save(modelContext: modelContext) {
                            dismiss()
                        }
                    }
                    .disabled(viewModel.ticker.isEmpty || viewModel.quantityText.isEmpty)
                }
            }
        }
    }
}
