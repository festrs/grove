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
    @State private var showRemoveAlert = false
    @State private var showingBuy = false
    @State private var showingSell = false

    /// Synchronous in-memory lookup so the first render has the holding —
    /// avoids a `TQLoadingView()` flash on every navigation. The viewModel
    /// still owns the reference for `refreshAll` / `removeHolding`, but
    /// rendering doesn't wait on the async `.task` to populate it.
    private var holding: Holding? {
        viewModel.holding ?? (modelContext.model(for: holdingID) as? Holding)
    }

    var body: some View {
        Group {
            if let holding {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.md) {
                            headerCard(holding)

                            // Custom (user-created) holdings have no backend
                            // record — chart, fundamentals, company info, and
                            // dividend history are all backend-sourced and
                            // would be empty/incorrect, so we skip them.
                            if !holding.isCustom, holding.assetClass.hasPriceHistory {
                                PriceChartView(ticker: holding.ticker, currency: holding.currency, backendService: backendService)
                            }

                            if !holding.isCustom {
                                HoldingStatsStrip(
                                    holding: holding,
                                    fundamentals: viewModel.fundamentals,
                                    isFundamentalsLoading: viewModel.isFundamentalsLoading
                                )

                                CompanyInfoCard(holding: holding)
                            }

                            let showDividends = !holding.isCustom && holding.assetClass.hasDividends
                            if sizeClass == .regular {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: Theme.Layout.regularCardMin), spacing: Theme.Spacing.md)],
                                    spacing: Theme.Spacing.md
                                ) {
                                    targetSection(holding)
                                    transactionHistorySection(holding)
                                    if showDividends {
                                        dividendHistorySection(holding)
                                    }
                                }
                            } else {
                                targetSection(holding)
                                transactionHistorySection(holding)
                                if showDividends {
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
                                showingSell = true
                            } label: {
                                Label("Sell", systemImage: "minus.circle.fill")
                            }
                            .keyboardShortcut("s", modifiers: .command)
                            .disabled(!holding.hasPosition)
                            .help("Sell (⌘S)")

                            Button {
                                showingBuy = true
                            } label: {
                                Label("Buy", systemImage: "plus.circle.fill")
                            }
                            .keyboardShortcut("b", modifiers: .command)
                            .help("Buy (⌘B)")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            showRemoveAlert = true
                        } label: {
                            Label("Remove Asset", systemImage: "trash")
                        }
                        .help("Remove Asset")
                    }
                }
                .sheet(isPresented: $showingBuy, onDismiss: reload) {
                    NewTransactionView(transactionType: .buy, preselectedHolding: holding)
                }
                .sheet(isPresented: $showingSell, onDismiss: reload) {
                    NewTransactionView(transactionType: .sell, preselectedHolding: holding)
                }
                .alert("Remove Asset", isPresented: $showRemoveAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Remove", role: .destructive) {
                        viewModel.removeHolding(modelContext: modelContext)
                        dismiss()
                    }
                } message: {
                    Text("Are you sure you want to remove \(holding.ticker) from your portfolio? This action cannot be undone.")
                }
                .refreshable {
                    if !holding.isCustom {
                        await viewModel.refreshAll(backendService: backendService)
                    }
                }
            } else {
                TQLoadingView()
            }
        }
        .task {
            viewModel.loadHolding(id: holdingID, modelContext: modelContext)
            if let holding = viewModel.holding, !holding.isCustom {
                await viewModel.refreshAll(backendService: backendService)
            }
        }
    }

    private func reload() {
        viewModel.loadHolding(id: holdingID, modelContext: modelContext)
    }

    private func actionBar(_ holding: Holding) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
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

            Button {
                showingBuy = true
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
