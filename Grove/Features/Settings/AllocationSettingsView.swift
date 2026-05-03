import SwiftUI
import SwiftData
import GroveDomain

struct AllocationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AllocationSettingsViewModel()

    var body: some View {
        Form {
            Section {
                TQAssetClassWeightsEditor(
                    weights: Binding(
                        get: { viewModel.weights },
                        set: { newValue in
                            for (cls, value) in newValue where viewModel.weights[cls] != value {
                                viewModel.setWeight(value, for: cls)
                            }
                        }
                    )
                )
            } header: {
                Text("Allocation by Class")
            } footer: {
                Text("Define how much of your total assets each class should represent. Must sum to 100%. Applies to all portfolios.")
            }

            if !viewModel.isValid {
                Section {
                    Text("Allocation must sum to 100%.")
                        .font(.caption)
                        .foregroundStyle(Color.tqNegative)
                }
            }
        }
        .navigationTitle("Allocation")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if viewModel.hasChanges {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save(modelContext: modelContext)
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
        .onAppear { viewModel.load(modelContext: modelContext) }
    }
}
