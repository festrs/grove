import SwiftUI
import SwiftData

struct HoldingDetailView: View {
    let holdingID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.dismiss) private var dismiss
    @State private var holding: Holding?
    @State private var showRemoveAlert = false
    @State private var showingBuy = false
    @State private var showingSell = false

    var body: some View {
        Group {
            if let holding {
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        headerCard(holding)
                        statsCard(holding)
                        assetClassSection(holding)
                        statusSection(holding)
                        targetSection(holding)
                        transactionHistorySection(holding)
                        dividendHistorySection(holding)
                    }
                    .padding(Theme.Spacing.md)
                }
                .navigationTitle(holding.ticker)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showingBuy = true
                            } label: {
                                Label("Comprar", systemImage: "plus.circle.fill")
                            }
                            Button {
                                showingSell = true
                            } label: {
                                Label("Vender", systemImage: "minus.circle.fill")
                            }
                            Divider()
                            Button(role: .destructive) {
                                showRemoveAlert = true
                            } label: {
                                Label("Remover ativo", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $showingBuy, onDismiss: reloadHolding) {
                    NewTransactionView(transactionType: .buy, preselectedHolding: holding)
                }
                .sheet(isPresented: $showingSell, onDismiss: reloadHolding) {
                    NewTransactionView(transactionType: .sell, preselectedHolding: holding)
                }
                .alert("Remover ativo", isPresented: $showRemoveAlert) {
                    Button("Cancelar", role: .cancel) {}
                    Button("Remover", role: .destructive) {
                        removeHolding()
                    }
                } message: {
                    Text("Tem certeza que deseja remover \(holding.ticker) do portfolio? Esta acao nao pode ser desfeita.")
                }
                .refreshable {
                    await refreshPrice()
                }
            } else {
                TQLoadingView()
            }
        }
        .task {
            holding = modelContext.model(for: holdingID) as? Holding
            await refreshPrice()
        }
    }

    private func reloadHolding() {
        holding = modelContext.model(for: holdingID) as? Holding
    }

    private func removeHolding() {
        guard let holding else { return }
        if holding.quantity > 0 {
            let contribution = Contribution(
                date: .now,
                amount: -(holding.quantity * holding.currentPrice),
                shares: -holding.quantity,
                pricePerShare: holding.currentPrice
            )
            contribution.holding = holding
            modelContext.insert(contribution)
        }
        modelContext.delete(holding)
        dismiss()
    }

    private func refreshPrice() async {
        guard let holding else { return }
        do {
            let quote = try await backendService.fetchStockQuote(symbol: holding.ticker)
            holding.currentPrice = quote.price.decimalAmount
            holding.lastPriceUpdate = .now
        } catch {
            // Keep cached price
        }
    }

    private func headerCard(_ holding: Holding) -> some View {
        TQCard {
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(holding.ticker)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(holding.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TQStatusBadge(status: holding.status)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading) {
                        Text("Preco atual")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(holding.currentPrice.formatted(as: holding.currency))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Quantidade")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(holding.quantity)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func statsCard(_ holding: Holding) -> some View {
        TQCard {
            VStack(spacing: Theme.Spacing.sm) {
                statRow("Valor total", holding.currentValue.formatted(as: holding.currency))
                statRow("Preco medio", holding.averagePrice.formatted(as: holding.currency))
                statRow("DY estimado", holding.dividendYield.formattedPercent())
                statRow("Renda mensal (liq.)", holding.estimatedMonthlyIncomeNet.formattedBRL())

                let gl = holding.gainLossPercent
                statRow("Ganho/Perda", "\(gl >= 0 ? "+" : "")\(gl.formattedPercent())",
                        valueColor: gl >= 0 ? Color.tqPositive : Color.tqNegative)
            }
        }
    }

    private func statRow(_ label: String, _ value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.medium).foregroundStyle(valueColor)
        }
    }

    private func assetClassSection(_ holding: Holding) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Classe do ativo").font(.headline)
                Picker("Classe", selection: Binding(
                    get: { holding.assetClass },
                    set: { holding.assetClass = $0 }
                )) {
                    ForEach(AssetClassType.allCases) { ct in
                        Label(ct.displayName, systemImage: ct.icon).tag(ct)
                    }
                }
            }
        }
    }

    private func statusSection(_ holding: Holding) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Status").font(.headline)
                Picker("Status", selection: Binding(
                    get: { holding.status },
                    set: { holding.status = $0 }
                )) {
                    ForEach(HoldingStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                Text(holding.status.description).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func targetSection(_ holding: Holding) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Peso na alocacao").font(.headline)
                HStack {
                    Slider(
                        value: Binding(
                            get: { NSDecimalNumber(decimal: holding.targetPercent).doubleValue },
                            set: { holding.targetPercent = Decimal($0) }
                        ),
                        in: 0...20, step: 1
                    )
                    .tint(.tqAccentGreen)
                    Text("\(NSDecimalNumber(decimal: holding.targetPercent).intValue)")
                        .font(.headline)
                        .monospacedDigit()
                        .frame(width: 30)
                }
                Text("Peso relativo para rebalanceamento. Todos os ativos comecam com peso 5.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func transactionHistorySection(_ holding: Holding) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Historico de transacoes").font(.headline)

                let contributions = holding.contributions.sorted(by: { $0.date > $1.date })
                if contributions.isEmpty {
                    Text("Nenhuma transacao registrada.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.vertical, Theme.Spacing.sm)
                } else {
                    ForEach(contributions.prefix(15), id: \.date) { c in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.shares > 0 ? "Compra" : "Venda")
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(c.shares > 0 ? Color.tqAccentGreen : Color.orange)
                                Text(c.date, style: .date)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(c.shares > 0 ? "+" : "")\(c.shares) cotas")
                                    .font(.subheadline).fontWeight(.medium)
                                Text(c.pricePerShare.formatted(as: holding.currency) + "/cota")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dividendHistorySection(_ holding: Holding) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Historico de dividendos").font(.headline)

                if holding.dividends.isEmpty {
                    VStack(spacing: Theme.Spacing.xs) {
                        Text("Renda mensal estimada")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(holding.estimatedMonthlyIncomeNet.formattedBRL())
                            .font(.headline).foregroundStyle(Color.tqAccentGreen)
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                } else {
                    ForEach(holding.dividends.sorted(by: { $0.paymentDate > $1.paymentDate }).prefix(10), id: \.paymentDate) { div in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(div.taxTreatment.displayName)
                                    .font(.caption).fontWeight(.medium)
                                Text(div.paymentDate, style: .date)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(div.netAmount.formattedBRL())
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundStyle(Color.tqAccentGreen)
                        }
                    }
                }
            }
        }
    }
}
