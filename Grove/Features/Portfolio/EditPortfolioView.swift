import SwiftUI
import SwiftData

struct EditPortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var portfolio: Portfolio
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Portfolio Name", text: $portfolio.name)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack { Spacer(); Text("Delete Portfolio"); Spacer() }
                    }
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
            .alert("Delete Portfolio", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    modelContext.delete(portfolio)
                    dismiss()
                }
            } message: {
                Text("All assets in this portfolio will be removed.")
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 400)
        #endif
    }
}
