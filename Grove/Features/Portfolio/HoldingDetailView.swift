import SwiftUI
import SwiftData
import GroveDomain

struct HoldingDetailView: View {
    let holdingID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var viewModel = HoldingDetailViewModel()

    private var holding: Holding? {
        viewModel.resolvedHolding(id: holdingID, modelContext: modelContext)
    }

    var body: some View {
        Group {
            if let holding {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.md) {
                            headerCard(holding)

                            if holding.hasPriceChartContent {
                                PriceChartView(ticker: holding.ticker, currency: holding.currency, backendService: backendService)
                            }

                            if holding.hasBackendEnrichment {
                                HoldingStatsStrip(
                                    holding: holding,
                                    fundamentals: viewModel.fundamentals,
                                    isFundamentalsLoading: viewModel.isFundamentalsLoading
                                )

                                CompanyInfoCard(holding: holding)
                            }

                            if sizeClass == .regular {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: Theme.Layout.regularCardMin), spacing: Theme.Spacing.md)],
                                    spacing: Theme.Spacing.md
                                ) {
                                    targetSection(holding)
                                    transactionHistorySection(holding)
                                    if holding.hasDividendHistoryContent {
                                        dividendHistorySection(holding)
                                    }
                                }
                            } else {
                                targetSection(holding)
                                transactionHistorySection(holding)
                                if holding.hasDividendHistoryContent {
                                    dividendHistorySection(holding)
                                }
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .frame(maxWidth: Theme.Layout.maxContentWidth)
                    }

                    #if os(iOS)
                    if sizeClass != .regular {
                        actionBar(holding)
                    }
                    #endif
                }
                .navigationTitle(holding.displayTicker)
                .toolbar {
                    if sizeClass == .regular {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button {
                                viewModel.showingSell = true
                            } label: {
                                Label("Sell", systemImage: "minus.circle.fill")
                            }
                            .keyboardShortcut("s", modifiers: .command)
                            .disabled(!holding.hasPosition)
                            .help("Sell (⌘S)")

                            Button {
                                viewModel.showingBuy = true
                            } label: {
                                Label("Buy", systemImage: "plus.circle.fill")
                            }
                            .keyboardShortcut("b", modifiers: .command)
                            .help("Buy (⌘B)")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            viewModel.showRemoveAlert = true
                        } label: {
                            Label("Remove Asset", systemImage: "trash")
                        }
                        .help("Remove Asset")
                    }
                }
                .sheet(isPresented: $viewModel.showingBuy, onDismiss: reload) {
                    NewTransactionView(transactionType: .buy, preselectedHolding: holding)
                }
                .sheet(isPresented: $viewModel.showingSell, onDismiss: reload) {
                    NewTransactionView(transactionType: .sell, preselectedHolding: holding)
                }
                .alert("Remove Asset", isPresented: $viewModel.showRemoveAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Remove", role: .destructive) {
                        viewModel.removeHolding(modelContext: modelContext)
                        dismiss()
                    }
                } message: {
                    Text("Are you sure you want to remove \(holding.ticker) from your portfolio? This action cannot be undone.")
                }
                .refreshable {
                    await viewModel.refreshIfNeeded(backendService: backendService)
                }
            } else {
                TQLoadingView()
            }
        }
        .task {
            await viewModel.onAppear(id: holdingID, modelContext: modelContext, backendService: backendService)
        }
    }

    private func reload() {
        viewModel.loadHolding(id: holdingID, modelContext: modelContext)
    }

    private func actionBar(_ holding: Holding) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                viewModel.showingSell = true
            } label: {
                Label("Sell", systemImage: "minus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(!holding.hasPosition)

            Button {
                viewModel.showingBuy = true
            } label: {
                Label("Buy", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.tqAccentGreen)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.ultraThinMaterial)
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
                TQPriorityPicker(
                    value: Binding(
                        get: { holding.targetPercent },
                        set: { holding.targetPercent = $0 }
                    ),
                    variant: .full
                )
            }
        }
    }

    private func transactionHistorySection(_ holding: Holding) -> some View {
        TQCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Transaction History").font(.headline)

                let transactions = holding.recentTransactions
                if transactions.isEmpty {
                    Text("No transactions recorded.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.vertical, Theme.Spacing.sm)
                } else {
                    ForEach(transactions, id: \.date) { c in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.isBuy ? "Buy" : "Sell")
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(c.isBuy ? Color.tqAccentGreen : Color.orange)
                                Text(c.date, style: .date)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(c.isBuy ? "+" : "")\(c.shares) shares")
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

                let earned = holding.paidDividends
                if earned.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Estimated Monthly Income")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(holding.estimatedMonthlyIncomeNetMoney().formatted())
                            .font(.headline).foregroundStyle(Color.tqAccentGreen)
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                } else {
                    ForEach(earned, id: \.paymentDate) { div in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(div.taxTreatment.displayName)
                                    .font(.caption).fontWeight(.medium)
                                Text(div.paymentDate, style: .date)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(div.netAmountMoney.formatted())
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
