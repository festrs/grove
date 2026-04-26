import SwiftUI
import SwiftData

struct HoldingDetailView: View {
    let holdingID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var holding: Holding?
    @State private var showRemoveAlert = false
    @State private var showingBuy = false
    @State private var showingSell = false
    @State private var fundamentals: FundamentalsDTO?
    @State private var isFundamentalsLoading = false

    var body: some View {
        Group {
            if let holding {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.md) {
                            headerCard(holding)

                            if holding.assetClass.hasPriceHistory {
                                PriceChartView(ticker: holding.ticker, currency: holding.currency, backendService: backendService)
                            }

                            HoldingStatsStrip(
                                holding: holding,
                                fundamentals: fundamentals,
                                isFundamentalsLoading: isFundamentalsLoading
                            )

                            CompanyInfoCard(holding: holding)

                            if sizeClass == .regular {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: Theme.Layout.regularCardMin), spacing: Theme.Spacing.md)],
                                    spacing: Theme.Spacing.md
                                ) {
                                    targetSection(holding)
                                    transactionHistorySection(holding)
                                    if holding.assetClass.hasDividends {
                                        dividendHistorySection(holding)
                                    }
                                }
                            } else {
                                targetSection(holding)
                                transactionHistorySection(holding)
                                if holding.assetClass.hasDividends {
                                    dividendHistorySection(holding)
                                }
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .frame(maxWidth: Theme.Layout.maxContentWidth)
                    }

                    actionBar(holding)
                }
                .navigationTitle(holding.displayTicker)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(role: .destructive) {
                                showRemoveAlert = true
                            } label: {
                                Label("Remove Asset", systemImage: "trash")
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
                .alert("Remove Asset", isPresented: $showRemoveAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Remove", role: .destructive) {
                        removeHolding()
                    }
                } message: {
                    Text("Are you sure you want to remove \(holding.ticker) from your portfolio? This action cannot be undone.")
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
        if holding.hasPosition {
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

    private func actionBar(_ holding: Holding) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                showingBuy = true
            } label: {
                Label("Buy", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.tqAccentGreen)

            Button {
                showingSell = true
            } label: {
                Label("Sell", systemImage: "minus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(!holding.hasPosition)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.ultraThinMaterial)
    }

    private func refreshPrice() async {
        guard let holding else { return }

        // Fetch quote and fundamentals concurrently
        async let quoteTask: Void = {
            do {
                let quote = try await backendService.fetchStockQuote(symbol: holding.ticker)
                holding.currentPrice = quote.price.decimalAmount
                holding.lastPriceUpdate = .now
            } catch {
                // Keep cached price
            }
        }()

        async let fundamentalsTask: Void = {
            guard holding.assetClass.hasFundamentals else { return }
            isFundamentalsLoading = true
            defer { isFundamentalsLoading = false }
            do {
                fundamentals = try await backendService.fetchFundamentals(symbol: holding.ticker)
            } catch {
                // Keep nil
            }
        }()

        _ = await (quoteTask, fundamentalsTask)
    }

    private func headerCard(_ holding: Holding) -> some View {
        TQCard {
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(holding.displayTicker)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(holding.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if sizeClass == .regular {
                        TQAssetClassPicker(selection: Binding(
                            get: { holding.assetClass },
                            set: { holding.assetClass = $0 }
                        ))
                        TQStatusPicker(selection: Binding(
                            get: { holding.status },
                            set: { holding.status = $0 }
                        ))
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading) {
                        Text("Current Price")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(holding.currentPrice.formatted(as: holding.currency))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Quantity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(holding.quantity)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }

                if sizeClass != .regular {
                    VStack(spacing: Theme.Spacing.xs) {
                        HStack {
                            Text("Class")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            TQAssetClassPicker(selection: Binding(
                                get: { holding.assetClass },
                                set: { holding.assetClass = $0 }
                            ))
                        }
                        HStack {
                            Text("Status")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            TQStatusPicker(selection: Binding(
                                get: { holding.status },
                                set: { holding.status = $0 }
                            ))
                        }
                    }
                }
            }
        }
    }

    private func targetSection(_ holding: Holding) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Allocation Weight").font(.headline)
                HStack {
                    Slider(
                        value: Binding(
                            get: { NSDecimalNumber(decimal: holding.targetPercent).doubleValue },
                            set: { holding.targetPercent = Decimal($0) }
                        ),
                        in: 1...5, step: 1
                    )
                    .tint(.tqAccentGreen)
                    Text("\(Int(NSDecimalNumber(decimal: holding.targetPercent).doubleValue))")
                        .font(.headline)
                        .monospacedDigit()
                        .frame(width: 30)
                }
                Text("Relative weight for rebalancing (1 = lowest, 5 = highest priority).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func transactionHistorySection(_ holding: Holding) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Transaction History").font(.headline)

                let contributions = holding.contributions.sorted(by: { $0.date > $1.date })
                if contributions.isEmpty {
                    Text("No transactions recorded.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.vertical, Theme.Spacing.sm)
                } else {
                    ForEach(contributions.prefix(15), id: \.date) { c in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.shares > 0 ? "Buy" : "Sell")
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(c.shares > 0 ? Color.tqAccentGreen : Color.orange)
                                Text(c.date, style: .date)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(c.shares > 0 ? "+" : "")\(c.shares) shares")
                                    .font(.subheadline).fontWeight(.medium)
                                Text(c.pricePerShare.formatted(as: holding.currency) + "/share")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dividendHistorySection(_ holding: Holding) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Dividend History").font(.headline)

                if holding.dividends.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Estimated Monthly Income")
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
