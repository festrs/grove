import SwiftUI
import SwiftData
import GroveDomain

struct AllocationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AllocationSettingsViewModel()

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

                        Text("\(Int(viewModel.weights[cls] ?? 0))%")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(viewModel.weights[cls] ?? 0 > 0 ? .primary : .secondary)
                            .frame(width: 44, alignment: .trailing)

                        Stepper("", value: Binding(
                            get: { viewModel.weights[cls] ?? 0 },
                            set: { viewModel.setWeight($0, for: cls) }
                        ), in: 0...100, step: 1)
                        .labelsHidden()
                    }
                }

                HStack {
                    Text("Total")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(viewModel.total))%")
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(viewModel.isValid ? Color.tqAccentGreen : Color.tqNegative)
                }
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
