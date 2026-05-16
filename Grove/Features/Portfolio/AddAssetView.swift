import SwiftUI
import SwiftData
import GroveDomain

/// Sheet shown after selecting a search result. Adds the asset to the
/// portfolio in one of two modes — track-only (no transaction) or with an
/// opening position (creates a `Transaction`). Used by both the live
/// portfolio search and the onboarding search flow.
struct AddAssetDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backendService) private var backendService
    @Environment(\.rates) private var rates
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AddAssetViewModel
    let mode: Mode

    enum Mode {
        /// Commit the holding (and optional transaction) directly to
        /// SwiftData via `AddAssetViewModel.addAsset`.
        case portfolio
        /// Buffer the form into the onboarding wizard's pending list. The
        /// caller appends the emitted `PendingHolding` to its view model.
        case onboarding(onAdd: (PendingHolding) -> Void)
    }

    init(searchResult: StockSearchResultDTO, assetClass: AssetClassType? = nil, mode: Mode = .portfolio) {
        _viewModel = State(initialValue: AddAssetViewModel(searchResult: searchResult, assetClass: assetClass))
        self.mode = mode
    }

    /// Custom-ticker entry point — user typed a symbol that didn't match any
    /// search result. Saves with `Holding.isCustom = true`.
    init(customSymbol: String, mode: Mode = .portfolio) {
        _viewModel = State(initialValue: AddAssetViewModel.custom(symbol: customSymbol))
        self.mode = mode
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    headerCard
                    classificationSection
                    prioritySection
                    positionToggle
                    if viewModel.ownsPosition {
                        positionSection
                    }
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.tqBackground)
            .navigationTitle("Add Asset")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.ownsPosition ? "Add Position" : "Track") {
                        confirm()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.isValid)
                }
            }
            .task { await viewModel.fetchPrice(backendService: backendService, rates: rates) }
        }
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 520, minHeight: 480, idealHeight: 560)
        #endif
    }

    private func confirm() {
        switch mode {
        case .portfolio:
            if viewModel.addAsset(modelContext: modelContext, backendService: backendService, rates: rates) {
                dismiss()
            }
        case .onboarding(let onAdd):
            guard viewModel.isValid else { return }
            onAdd(viewModel.toPendingHolding(rates: rates))
            dismiss()
        }
    }

    // MARK: - Sections

    private var headerCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(viewModel.detectedClass.color.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: viewModel.detectedClass.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(viewModel.detectedClass.color)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.searchResult.displaySymbol)
                    .font(.title3).fontWeight(.bold)
                if viewModel.isCustom {
                    Text("Custom ticker — local only")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let name = viewModel.searchResult.name {
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Color.tqCardBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    private var classificationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("Classification")
            VStack(spacing: Theme.Spacing.sm) {
                if viewModel.hasFixedClass {
                    fieldRow("Asset Class") {
                        Label(viewModel.detectedClass.displayName, systemImage: viewModel.detectedClass.icon)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    fieldRow("Asset Class") {
                        TQAssetClassPicker(selection: $viewModel.detectedClass)
                    }
                }
                Divider()
                fieldRow("Status") {
                    TQStatusPicker(selection: $viewModel.selectedStatus)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Color.tqCardBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("Priority")
            TQPriorityPicker(
                value: Binding(
                    get: { viewModel.targetPercent },
                    set: { viewModel.targetPercent = $0 }
                ),
                variant: .full
            )
            .padding(Theme.Spacing.md)
            .background(Color.tqCardBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
    }

    private var positionToggle: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Toggle(isOn: $viewModel.ownsPosition) {
                Text("Record current position")
                    .font(.body.weight(.medium))
            }
            .toggleStyle(.switch)
            Text(viewModel.ownsPosition
                 ? "Adds an opening transaction with quantity and average buy price."
                 : "Asset is added without a transaction. You can buy in later.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.md)
        .background(Color.tqCardBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionTitle("Position")
            VStack(spacing: Theme.Spacing.sm) {
                fieldRow("Quantity") {
                    TextField("0", text: $viewModel.quantityText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 160)
                }
                Divider()
                fieldRow("Avg Price (\(viewModel.currency.symbol))") {
                    if viewModel.isFetchingPrice {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        TextField("0,00", text: $viewModel.priceText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 160)
                    }
                }
                Divider()
                fieldRow("Date") {
                    DatePicker("", selection: $viewModel.date, displayedComponents: .date)
                        .labelsHidden()
                }
                if viewModel.totalValue > 0 {
                    Divider()
                    fieldRow("Total") {
                        Text(viewModel.totalValue.formatted(as: viewModel.currency))
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.tqAccentGreen)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(Color.tqCardBackground, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
    }

    // MARK: - Building blocks

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, Theme.Spacing.xs)
    }

    private func fieldRow<Trailing: View>(_ label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer(minLength: Theme.Spacing.md)
            trailing()
        }
    }
}

#Preview {
    AddAssetDetailSheet(
        searchResult: StockSearchResultDTO(
            id: "ITUB3.SA",
            symbol: "ITUB3.SA",
            name: "ITAU UNIBANCO HOLDING S.A.",
            type: "stock",
            price: MoneyDTO(amount: "46.37", currency: "BRL"),
            currency: "BRL",
            change: -0.92,
            sector: "Finance",
            logo: nil
        )
    )
        .modelContainer(for: [Portfolio.self, Holding.self, DividendPayment.self, GroveDomain.Transaction.self, UserSettings.self], inMemory: true)
}
