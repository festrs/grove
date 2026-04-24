import SwiftUI
import UniformTypeIdentifiers

/// Reusable import component used by both onboarding and portfolio import.
/// Handles text/file input → AI analysis → preview with checkboxes.
struct ImportView: View {
    @Bindable var viewModel: ImportViewModel
    @Environment(\.backendService) private var backendService

    var showFileOption: Bool = true
    var existingTickers: Set<String> = []
    var confirmLabel: String = "Importar"
    var onConfirm: ([ImportedPosition]) -> Void

    var body: some View {
        if viewModel.positions.isEmpty {
            inputPhase
        } else {
            previewPhase
        }
    }

    // MARK: - Input Phase

    private var inputPhase: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if showFileOption {
                Picker("Modo", selection: $viewModel.inputMode) {
                    Text("Texto").tag(ImportInputMode.text)
                    Text("Arquivo").tag(ImportInputMode.file)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.lg)
            }

            if viewModel.inputMode == .text || !showFileOption {
                textInput
            } else {
                fileInput
            }

            analyzeButton
        }
        .alert("Erro", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var textInput: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("Cole o texto do seu extrato ou lista de ativos")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundStyle(Color.tqSecondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.lg)

            TextEditor(text: $viewModel.pastedText)
                .font(.system(size: Theme.FontSize.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(Theme.Spacing.sm)
                .frame(minHeight: 120, maxHeight: 160)
                .background(Color.tqCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                .padding(.horizontal, Theme.Spacing.lg)

            Text("Aceita qualquer formato: tickers, CSV, extrato B3, texto copiado de planilha...")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundStyle(Color.tqSecondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.lg)
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
                        Button("Trocar arquivo") {
                            viewModel.showingFilePicker = true
                        }
                        .font(.subheadline)
                    } else {
                        Text("Selecione um arquivo de extrato")
                            .font(.subheadline)
                            .foregroundStyle(Color.tqSecondaryText)
                        Button("Escolher arquivo") {
                            viewModel.showingFilePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.tqAccentGreen)
                    }

                    Text("Formatos: .xlsx, .csv, .txt")
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
                        Text("Analisando...")
                    }
                } else {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "sparkles")
                        Text("Analisar")
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
                Text("\(viewModel.positions.count) ativos encontrados")
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundStyle(Color.tqSecondaryText)
                Spacer()
                Button("Voltar") { viewModel.reset() }
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Color.tqSecondaryText)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            ScrollView {
                LazyVStack(spacing: Theme.Spacing.xs) {
                    ForEach(viewModel.positions) { position in
                        positionRow(position)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .frame(maxHeight: 220)

            Button {
                let selected = viewModel.selectedPositions
                onConfirm(selected)
                viewModel.reset()
            } label: {
                let count = viewModel.selectedTickers.count
                Text("\(confirmLabel) \(count) ativo\(count == 1 ? "" : "s")")
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
            TQCard {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: alreadyAdded ? "checkmark.circle.fill" : isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(alreadyAdded ? Color.tqSecondaryText : isSelected ? Color.tqAccentGreen : Color.tqSecondaryText)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(position.displayTicker)
                                .font(.system(size: Theme.FontSize.body, weight: .semibold))
                            Text(position.assetClassType.shortName)
                                .font(.system(size: 10))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(position.assetClassType.color.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        if !position.displayName.isEmpty {
                            Text(position.displayName)
                                .font(.system(size: Theme.FontSize.caption))
                                .foregroundStyle(Color.tqSecondaryText)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if position.quantity > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(position.quantity) cotas")
                                .font(.system(size: Theme.FontSize.caption))
                            Text(Decimal(position.totalValue).formattedBRL())
                                .font(.system(size: Theme.FontSize.caption))
                                .foregroundStyle(Color.tqSecondaryText)
                        }
                    }
                }
            }
            .opacity(alreadyAdded ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(alreadyAdded)
    }
}
