import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum ImportInputMode {
    case file
    case text
}

@Observable
final class ImportViewModel {
    var inputMode: ImportInputMode = .text
    var showingFilePicker = false
    var selectedFileData: Data?
    var selectedFilename: String?
    var pastedText = ""
    var isLoading = false
    var positions: [ImportedPosition] = []
    var selectedTickers: Set<String> = []
    var showingError = false
    var errorMessage = ""

    var canAnalyze: Bool {
        guard !isLoading else { return false }
        switch inputMode {
        case .file: return selectedFileData != nil
        case .text: return !pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var selectedPositions: [ImportedPosition] {
        positions.filter { selectedTickers.contains($0.ticker) }
    }

    func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the file."
                showingError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                selectedFileData = try Data(contentsOf: url)
                selectedFilename = url.lastPathComponent
            } catch {
                errorMessage = "Error reading file: \(error.localizedDescription)"
                showingError = true
            }
        case .failure(let error):
            errorMessage = "Error selecting file: \(error.localizedDescription)"
            showingError = true
        }
    }

    func analyze(backendService: any BackendServiceProtocol) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fileData = inputMode == .file ? selectedFileData : nil
            let filename = inputMode == .file ? selectedFilename : nil
            let text = inputMode == .text ? pastedText : nil
            let result = try await backendService.importPortfolio(
                fileData: fileData,
                filename: filename,
                text: text
            )
            positions = result
            let tickers = result.map(\.ticker)
            if let max = maxSelectable {
                selectedTickers = Set(tickers.prefix(max))
            } else {
                selectedTickers = Set(tickers)
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    var maxSelectable: Int?

    func toggleSelection(_ ticker: String) {
        if selectedTickers.contains(ticker) {
            selectedTickers.remove(ticker)
        } else {
            if let max = maxSelectable, selectedTickers.count >= max {
                return
            }
            selectedTickers.insert(ticker)
        }
    }

    func reset() {
        positions = []
        selectedTickers = []
    }
}
