import SwiftUI
import SwiftData

struct AllocationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var weights: [AssetClassType: Double] = [:]
    @State private var hasChanges = false

    private var total: Double {
        weights.values.reduce(0, +)
    }

    private var isValid: Bool {
        abs(total - 100) < 0.5
    }

    var body: some View {
        Form {
            Section {
                ForEach(AssetClassType.allCases) { cls in
                    HStack {
                        Circle()
                            .fill(cls.color)
                            .frame(width: 10, height: 10)
                        Text(cls.displayName)
                            .font(.subheadline)

                        Spacer()

                        Text("\(Int(weights[cls] ?? 0))%")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(weights[cls] ?? 0 > 0 ? .primary : .secondary)
                            .frame(width: 44, alignment: .trailing)

                        Stepper("", value: Binding(
                            get: { weights[cls] ?? 0 },
                            set: {
                                weights[cls] = $0
                                hasChanges = true
                            }
                        ), in: 0...100, step: 1)
                        .labelsHidden()
                    }
                }

                HStack {
                    Text("Total")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(total))%")
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(isValid ? Color.tqAccentGreen : Color.tqNegative)
                }
            } header: {
                Text("Allocation by Class")
            } footer: {
                Text("Define how much of your total assets each class should represent. Must sum to 100%. Applies to all portfolios.")
            }

            if !isValid {
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
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .onAppear { load() }
    }

    private func load() {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        if let settings = try? modelContext.fetch(descriptor).first {
            weights = settings.classAllocations
        }
        // Fill missing classes with 0
        for cls in AssetClassType.allCases {
            if weights[cls] == nil { weights[cls] = 0 }
        }
    }

    private func save() {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        if let settings = try? modelContext.fetch(descriptor).first {
            settings.classAllocations = weights
            try? modelContext.save()
            hasChanges = false
        }
    }
}
