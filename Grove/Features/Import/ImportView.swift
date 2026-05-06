import SwiftUI
import UniformTypeIdentifiers
import GroveDomain

/// Reusable import component used by both onboarding and portfolio import.
/// Handles file input → AI analysis → preview with checkboxes.
struct ImportView: View {
    @Bindable var viewModel: ImportViewModel
    @Environment(\.backendService) private var backendService

    var existingTickers: Set<String> = []
    var confirmLabel: String = "Import"
    var onConfirm: ([ImportedPosition]) -> Void

    var body: some View {
        VStack {
            if viewModel.positions.isEmpty {
                inputPhase
            } else {
                previewPhase
            }
            Spacer()
        }
    }

    // MARK: - Input Phase

    private var inputPhase: some View {
        VStack(spacing: Theme.Spacing.sm) {
            fileInput
            analyzeButton
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var fileInput: some View {
        VStack(spacing: Theme.Spacing.md) {
            TQCard {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.tqSecondaryText)

                    if let filename = viewModel.selectedFilename {
                        Text(filename)
                            .font(.headline)
                        Button("Change File") {
                            viewModel.showingFilePicker = true
                        }
                        .font(.subheadline)
                    } else {
                        Text("Select a statement file")
                            .font(.subheadline)
                            .foregroundStyle(Color.tqSecondaryText)
                        Button("Choose File") {
                            viewModel.showingFilePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.tqAccentGreen)
                    }

                    Text("Formats: .xlsx, .csv, .txt")
                        .font(.caption)
                        .foregroundStyle(Color.tqSecondaryText)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .fileImporter(
            isPresented: $viewModel.showingFilePicker,
            allowedContentTypes: [.commaSeparatedText, .plainText, .spreadsheet, .xlsx],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleFileSelection(result)
        }
    }

    private var analyzeButton: some View {
        Button {
            Task { await viewModel.analyze(backendService: backendService) }
        } label: {
            Group {
                if viewModel.isLoading {
                    HStack(spacing: Theme.Spacing.xs) {
                        ProgressView().tint(.white)
                        Text("Analyzing...")
                    }
                } else {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "sparkles")
                        Text("Analyze")
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Color.tqAccentGreen)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .disabled(!viewModel.canAnalyze)
    }

    // MARK: - Preview Phase

    private var previewPhase: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("\(viewModel.positions.count) assets found")
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundStyle(Color.tqSecondaryText)
                Spacer()
                Button("Back") { viewModel.reset() }
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Color.tqSecondaryText)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            if let max = viewModel.maxSelectable {
                Text("Free plan: select up to \(max) asset\(max == 1 ? "" : "s")")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(viewModel.selectedTickers.count >= max ? Color.orange : Color.tqSecondaryText)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            ScrollView {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(viewModel.positions) { position in
                        positionRow(position)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }

            Button {
                let selected = viewModel.selectedPositions
                onConfirm(selected)
                viewModel.reset()
            } label: {
                let count = viewModel.selectedTickers.count
                Text("\(confirmLabel) \(count) asset\(count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Color.tqAccentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .disabled(viewModel.selectedTickers.isEmpty)
        }
    }

    private func positionRow(_ position: ImportedPosition) -> some View {
        let isSelected = viewModel.selectedTickers.contains(position.ticker)
        let alreadyAdded = existingTickers.contains(position.ticker.uppercased())

        return Button {
            guard !alreadyAdded else { return }
            viewModel.toggleSelection(position.ticker)
        } label: {
            TQTickerRow(
                ticker: position.displayTicker,
                subtitle: position.displayName,
                assetClass: position.assetClassType,
                showCheckbox: true,
                isSelected: isSelected || alreadyAdded,
                isDisabled: alreadyAdded,
                showClassBadge: true,
                trailingTitle: position.quantity > 0 ? "\(position.displayQuantity) shares" : nil,
                trailingSubtitle: position.quantity > 0 ? Money(amount: Decimal(position.totalValue), currency: .brl).formatted() : nil
            )
        }
        .buttonStyle(.plain)
        .disabled(alreadyAdded)
    }
}
