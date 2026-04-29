import SwiftUI
import SwiftData
import GroveDomain

struct NewTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.dismiss) private var dismiss
    @Query private var holdings: [Holding]

    let transactionType: TransactionType
    var preselectedHolding: Holding? = nil

    @State private var viewModel: NewTransactionViewModel
    @State private var debouncer = SearchDebouncer()

    init(transactionType: TransactionType, preselectedHolding: Holding? = nil) {
        self.transactionType = transactionType
        self.preselectedHolding = preselectedHolding
        _viewModel = State(initialValue: NewTransactionViewModel(transactionType: transactionType))
    }

    enum TransactionType: String {
        case buy = "buy"
        case sell = "sell"

        var title: String {
            switch self {
            case .buy: "Buy"
            case .sell: "Sell"
            }
        }

        var color: Color {
            switch self {
            case .buy: .tqAccentGreen
            case .sell: .orange
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                assetSection
                if viewModel.selectedHolding != nil || !viewModel.newTicker.isEmpty {
                    detailsSection
                    summarySection
                }
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(transactionType.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                viewModel.applyPreselection(preselectedHolding)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        if viewModel.submit(modelContext: modelContext, backendService: backendService) {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        .frame(minWidth: 560, idealWidth: 620, minHeight: 460)
        #endif
    }

    // MARK: - Asset Section

    private var assetSection: some View {
        Section("Asset") {
            if preselectedHolding != nil, let holding = viewModel.selectedHolding {
                // Opened from holding detail — show fixed header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(holding.ticker)
                            .font(.headline)
                        Text(holding.displayName)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if transactionType == .sell {
                        Text("\(holding.quantity) shares")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } else if transactionType == .sell {
                Picker("Asset", selection: $viewModel.selectedHolding) {
                    Text("Select").tag(nil as Holding?)
                    ForEach(holdings.filter { $0.quantity > 0 }, id: \.ticker) { holding in
                        Text("\(holding.ticker) (\(holding.quantity) shares)")
                            .tag(holding as Holding?)
                    }
                }
            } else {
                Picker("Mode", selection: $viewModel.isNewAsset) {
                    Text("Existing").tag(false)
                    Text("New Asset").tag(true)
                }
                .pickerStyle(.segmented)

                if viewModel.isNewAsset {
                    newAssetSearch
                } else {
                    Picker("Asset", selection: $viewModel.selectedHolding) {
                        Text("Select").tag(nil as Holding?)
                        ForEach(holdings, id: \.ticker) { holding in
                            Text("\(holding.ticker) — \(holding.displayName)")
                                .tag(holding as Holding?)
                        }
                    }
                }
            }
        }
    }

    private var newAssetSearch: some View {
        Group {
            TextField("Search ticker (e.g.: ITUB3, AAPL)", text: Binding(
                get: { viewModel.newTicker },
                set: { viewModel.newTicker = $0 }
            ))
            #if os(iOS)
            .textInputAutocapitalization(.characters)
            #endif
            .autocorrectionDisabled()
            .onAppear {
                let svc = backendService
                debouncer.start { query in
                    (try? await svc.searchStocks(query: query)) ?? []
                }
            }
            .onDisappear { debouncer.stop() }
            .onChange(of: viewModel.newTicker) { _, newValue in
                debouncer.send(newValue)
            }

            if debouncer.isSearching {
                HStack { ProgressView(); Text("Searching...").font(.caption).foregroundStyle(.secondary) }
            }

            ForEach(debouncer.results) { result in
                Button {
                    viewModel.selectSearchResult(result, backendService: backendService)
                    debouncer.results = []
                } label: {
                    HStack {
                        Text(result.symbol).fontWeight(.semibold)
                        if let name = result.name { Text(name).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .foregroundStyle(.primary)
            }

            if !viewModel.newTicker.isEmpty {
                LabeledContent("Ticker", value: viewModel.newTicker)
                if !viewModel.newDisplayName.isEmpty {
                    LabeledContent("Name", value: viewModel.newDisplayName)
                }
                Picker("Class", selection: $viewModel.newAssetClass) {
                    ForEach(AssetClassType.allCases) { ct in
                        Text(ct.displayName).tag(ct)
                    }
                }
            }
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Quantity") {
                TextField("0", text: $viewModel.quantityText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 120)
            }

            if let holding = viewModel.selectedHolding, transactionType == .sell {
                Text("Available: \(holding.quantity) shares")
                    .font(.caption).foregroundStyle(.secondary)
            }

            LabeledContent("Price (\(viewModel.currency.symbol))") {
                TextField("0,00", text: $viewModel.priceText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 120)
            }

            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)

            LabeledContent("Notes") {
                TextField("optional", text: $viewModel.notes)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            LabeledContent(transactionType == .buy ? "Total Invested" : "Total Withdrawn") {
                Text(viewModel.totalValue.formatted(as: viewModel.currency))
                    .fontWeight(.bold)
                    .foregroundStyle(transactionType.color)
            }
        }
    }
}

#Preview {
    NewTransactionView(transactionType: .buy)
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self], inMemory: true)
}
