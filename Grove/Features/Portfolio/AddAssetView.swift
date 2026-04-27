import SwiftUI
import SwiftData
import GroveDomain

/// Sheet shown after selecting a search result from the portfolio search bar.
/// Collects quantity, price, and asset class to add the holding.
struct AddAssetDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.dismiss) private var dismiss

    let searchResult: StockSearchResultDTO

    @State private var detectedClass: AssetClassType
    @State private var quantityText = ""
    @State private var priceText = ""
    @State private var date = Date.now
    @State private var isFetchingPrice = false
    @State private var error: String?

    init(searchResult: StockSearchResultDTO) {
        self.searchResult = searchResult
        _detectedClass = State(initialValue: AssetClassType.detect(from: searchResult.symbol, apiType: searchResult.type) ?? .acoesBR)
    }

    private var quantity: Decimal? {
        Decimal(string: quantityText.replacingOccurrences(of: ",", with: "."))
    }

    private var price: Decimal? {
        Decimal(string: priceText.replacingOccurrences(of: ",", with: "."))
    }

    private var currency: Currency {
        detectedClass.defaultCurrency
    }

    private var totalValue: Decimal {
        guard let q = quantity, let p = price else { return 0 }
        return q * p
    }

    private var isValid: Bool {
        (quantity ?? 0) > 0 && (price ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Asset header
                Section {
                    HStack {
                        Circle()
                            .fill(detectedClass.color.opacity(0.15))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: detectedClass.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(detectedClass.color)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(searchResult.symbol)
                                .font(.title3).fontWeight(.bold)
                            if let name = searchResult.name {
                                Text(name)
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Asset Class") {
                    Picker("Class", selection: $detectedClass) {
                        ForEach(AssetClassType.allCases) { ct in
                            HStack {
                                Image(systemName: ct.icon)
                                Text(ct.displayName)
                            }
                            .tag(ct)
                        }
                    }
                }

                Section("Purchase Details") {
                    LabeledContent("Quantity") {
                        TextField("0", text: $quantityText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Price (\(currency.symbol))") {
                        if isFetchingPrice {
                            ProgressView()
                        } else {
                            TextField("0,00", text: $priceText)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                if totalValue > 0 {
                    Section {
                        HStack {
                            Text("Total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(totalValue.formatted(as: currency))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.tqAccentGreen)
                        }
                    }
                }

                if let error {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
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
                    Button("Add") { addAsset() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .task {
                await fetchPrice()
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, idealWidth: 560, minHeight: 420)
        #endif
    }

    private func fetchPrice() async {
        // Use price from search result if available
        if let p = searchResult.priceDecimal, p > 0 {
            priceText = "\(p)"
            return
        }
        isFetchingPrice = true
        defer { isFetchingPrice = false }
        if let quote = try? await backendService.fetchStockQuote(symbol: searchResult.symbol) {
            priceText = "\(quote.price.decimalAmount)"
        }
    }

    private func addAsset() {
        guard let qty = quantity, let prc = price else { return }

        guard Holding.canAddMore(modelContext: modelContext) else {
            error = Holding.freeTierLimitMessage
            return
        }

        let holding = Holding(
            ticker: searchResult.symbol,
            displayName: searchResult.name ?? searchResult.symbol,
            currentPrice: prc,
            assetClass: detectedClass,
            status: .aportar
        )
        holding.sector = searchResult.sector
        holding.logoURL = searchResult.logo

        var descriptor = FetchDescriptor<Portfolio>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        if let portfolio = try? modelContext.fetch(descriptor).first {
            holding.portfolio = portfolio
        } else {
            let portfolio = Portfolio()
            modelContext.insert(portfolio)
            holding.portfolio = portfolio
        }
        modelContext.insert(holding)

        let contribution = Contribution(
            date: date,
            amount: qty * prc,
            shares: qty,
            pricePerShare: prc
        )
        contribution.holding = holding
        modelContext.insert(contribution)

        holding.recalculateFromContributions()

        // Tell backend to track this symbol for price/dividend updates
        Task {
            try? await backendService.trackSymbol(
                symbol: searchResult.symbol,
                assetClass: detectedClass.rawValue
            )
        }

        dismiss()
    }
}

#Preview {
    AddAssetDetailSheet(searchResult: StockSearchResultDTO(id: "ITUB3.SA", symbol: "ITUB3.SA", name: "ITAU UNIBANCO HOLDING S.A.", type: "stock", price: "46.37", currency: "BRL", change: "-0.92", sector: "Finance", logo: nil))
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self], inMemory: true)
}
