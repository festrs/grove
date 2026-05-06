import SwiftUI
import SwiftData
import GroveDomain

struct EditPortfolioView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var portfolio: Portfolio

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Portfolio Name", text: $portfolio.name)
                }
            }
            .navigationTitle("Edit Portfolio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 400)
        #endif
    }
}
