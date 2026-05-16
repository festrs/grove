import SwiftUI
import SwiftData
import GroveDomain

struct AllocationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [UserSettings]

    @State private var weights: [AssetClassType: Double] = .defaultAssetClassZeros
    @State private var loaded = false

    private var settings: UserSettings? { allSettings.first }

    private var hasChanges: Bool {
        guard let stored = settings?.classAllocations.withMissingAssetClassZeros else { return false }
        return weights != stored
    }

    var body: some View {
        Form {
            Section {
                TQAssetClassWeightsEditor(weights: $weights)
            } header: {
                Text("Allocation by Class")
            } footer: {
                Text("Define how much of your total assets each class should represent. Must sum to 100%.")
            }

            if !weights.isValidAllocation {
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
            if hasChanges {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!weights.isValidAllocation)
                }
            }
        }
        .task {
            guard !loaded else { return }
            weights = settings?.classAllocations.withMissingAssetClassZeros ?? .defaultAssetClassZeros
            loaded = true
        }
    }

    private func save() {
        guard weights.isValidAllocation, let settings else { return }
        settings.classAllocations = weights
        try? modelContext.save()
    }
}
