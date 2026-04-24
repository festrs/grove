import SwiftUI
import SwiftData

struct NewTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.dismiss) private var dismiss
    @Query private var holdings: [Holding]

    let transactionType: TransactionType
    var preselectedHolding: Holding? = nil

    @State private var searchQuery = ""
    @State private var debouncer = SearchDebouncer()

    @State private var selectedHolding: Holding?
    @State private var isNewAsset = false
    @State private var newTicker = ""
    @State private var newDisplayName = ""
    @State private var newAssetClass: AssetClassType = .acoesBR

    @State private var quantityText = ""
    @State private var priceText = ""
    @State private var date = Date.now
    @State private var notes = ""

    @State private var error: String?

    enum TransactionType: String {
        case buy = "buy"
        case sell = "sell"

        var title: String {
            switch self {
            case .buy: "Comprar"
            case .sell: "Vender"
            }
        }

        var color: Color {
            switch self {
            case .buy: .tqAccentGreen
            case .sell: .orange
            }
        }
    }

    private var quantity: Decimal? {
        Decimal(string: quantityText.replacingOccurrences(of: ",", with: "."))
    }

    private var price: Decimal? {
        Decimal(string: priceText.replacingOccurrences(of: ",", with: "."))
    }

    private var totalValue: Decimal {
        guard let q = quantity, let p = price else { return 0 }
        return q * p
    }

    private var currency: Currency {
        selectedHolding?.currency ?? newAssetClass.defaultCurrency
    }

    private var isValid: Bool {
        let hasAsset = selectedHolding != nil || !newTicker.isEmpty
        let hasQty = (quantity ?? 0) > 0
        let hasPrice = (price ?? 0) > 0
        if transactionType == .sell, let holding = selectedHolding, let qty = quantity {
            return hasAsset && hasQty && hasPrice && qty <= holding.quantity
        }
        return hasAsset && hasQty && hasPrice
    }

    var body: some View {
        NavigationStack {
            Form {
                assetSection
                if selectedHolding != nil || !newTicker.isEmpty {
                    detailsSection
                    summarySection
                }
                if let error {
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
                if let preselectedHolding, selectedHolding == nil {
                    selectedHolding = preselectedHolding
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") { submit() }
                        .disabled(!isValid)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 400)
        #endif
    }

    // MARK: - Asset Section

    private var assetSection: some View {
        Section("Ativo") {
            if preselectedHolding != nil, let holding = selectedHolding {
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
                        Text("\(holding.quantity) cotas")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } else if transactionType == .sell {
                Picker("Ativo", selection: $selectedHolding) {
                    Text("Selecionar").tag(nil as Holding?)
                    ForEach(holdings.filter { $0.quantity > 0 }, id: \.ticker) { holding in
                        Text("\(holding.ticker) (\(holding.quantity) cotas)")
                            .tag(holding as Holding?)
                    }
                }
            } else {
                Picker("Modo", selection: $isNewAsset) {
                    Text("Existente").tag(false)
                    Text("Novo ativo").tag(true)
                }
                .pickerStyle(.segmented)

                if isNewAsset {
                    newAssetSearch
                } else {
                    Picker("Ativo", selection: $selectedHolding) {
                        Text("Selecionar").tag(nil as Holding?)
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
            TextField("Buscar ticker (ex: ITUB3, AAPL)", text: $searchQuery)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                #endif
                .autocorrectionDisabled()
                .onAppear {
                    debouncer.start { query in
                        (try? await backendService.searchStocks(query: query)) ?? []
                    }
                }
                .onDisappear { debouncer.stop() }
                .onChange(of: searchQuery) { _, newValue in
                    debouncer.send(newValue)
                }

            if debouncer.isSearching {
                HStack { ProgressView(); Text("Buscando...").font(.caption).foregroundStyle(.secondary) }
            }

            ForEach(debouncer.results) { result in
                Button {
                    newTicker = result.symbol
                    newDisplayName = result.name ?? result.symbol
                    if let detected = AssetClassType.detect(from: result.symbol) {
                        newAssetClass = detected
                    }
                    debouncer.results = []
                    Task {
                        if let quote = try? await backendService.fetchStockQuote(symbol: result.symbol) {
                            priceText = "\(quote.price.decimalAmount)"
                        }
                    }
                } label: {
                    HStack {
                        Text(result.symbol).fontWeight(.semibold)
                        if let name = result.name { Text(name).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .foregroundStyle(.primary)
            }

            if !newTicker.isEmpty {
                LabeledContent("Ticker", value: newTicker)
                if !newDisplayName.isEmpty {
                    LabeledContent("Nome", value: newDisplayName)
                }
                Picker("Classe", selection: $newAssetClass) {
                    ForEach(AssetClassType.allCases) { ct in
                        Text(ct.displayName).tag(ct)
                    }
                }
            }
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        Section("Detalhes") {
            HStack {
                Text("Quantidade")
                Spacer()
                TextField("0", text: $quantityText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }

            if let holding = selectedHolding, transactionType == .sell {
                Text("Disponivel: \(holding.quantity) cotas")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Text("Preco (\(currency.symbol))")
                Spacer()
                TextField("0,00", text: $priceText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }

            DatePicker("Data", selection: $date, displayedComponents: .date)
            TextField("Notas (opcional)", text: $notes)
        }
    }

    private var summarySection: some View {
        Section("Resumo") {
            HStack {
                Text(transactionType == .buy ? "Total investido" : "Total resgatado")
                    .fontWeight(.semibold)
                Spacer()
                Text(totalValue.formatted(as: currency))
                    .fontWeight(.bold)
                    .foregroundStyle(transactionType.color)
            }
        }
    }

    // MARK: - Actions

    private func submit() {
        guard let qty = quantity, let prc = price else { return }

        if transactionType == .buy {
            handleBuy(quantity: qty, price: prc)
        } else {
            handleSell(quantity: qty, price: prc)
        }

        dismiss()
    }

    private func handleBuy(quantity: Decimal, price: Decimal) {
        let holding: Holding

        if let existing = selectedHolding {
            existing.currentPrice = price
            holding = existing
        } else {
            holding = Holding(
                ticker: newTicker,
                displayName: newDisplayName.isEmpty ? newTicker : newDisplayName,
                currentPrice: price,
                assetClass: newAssetClass,
                status: .aportar
            )
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
        }

        let contribution = Contribution(date: date, amount: quantity * price, shares: quantity, pricePerShare: price)
        contribution.holding = holding
        modelContext.insert(contribution)

        // If holding was in estudo, promote to aportar on first buy
        if holding.status == .estudo {
            holding.status = .aportar
        }

        holding.recalculateFromContributions()
    }

    private func handleSell(quantity: Decimal, price: Decimal) {
        guard let holding = selectedHolding else { return }

        let contribution = Contribution(date: date, amount: -(quantity * price), shares: -quantity, pricePerShare: price)
        contribution.holding = holding
        modelContext.insert(contribution)

        holding.recalculateFromContributions()

        if holding.quantity <= 0 {
            modelContext.delete(holding)
        }
    }
}

#Preview {
    NewTransactionView(transactionType: .buy)
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, Contribution.self, UserSettings.self], inMemory: true)
}
