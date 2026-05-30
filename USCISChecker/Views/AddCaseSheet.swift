import SwiftUI

struct AddCaseSheet: View {
    @EnvironmentObject var store: CaseStore
    @Environment(\.dismiss) private var dismiss

    @State private var receiptNumber = ""
    @State private var nickname = ""
    @State private var isChecking = false
    @State private var fieldError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Receipt Number (e.g. IOE1234567890)", text: $receiptNumber)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .onChange(of: receiptNumber) { _, _ in fieldError = nil }
                    if let error = fieldError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    TextField("Nickname (optional)", text: $nickname)
                }
            }
            .navigationTitle("Add Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Check & Save") {
                        Task { await checkAndSave() }
                    }
                    .disabled(receiptNumber.trimmingCharacters(in: .whitespaces).isEmpty || isChecking)
                }
            }
            .overlay {
                if isChecking {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
    }

    private func checkAndSave() async {
        let trimmed = receiptNumber.trimmingCharacters(in: .whitespaces).uppercased()
        guard ReceiptValidator.isValid(trimmed) else {
            fieldError = "Invalid format — expected e.g. IOE1234567890"
            return
        }
        isChecking = true
        let record = CaseRecord(receiptNumber: trimmed, nickname: nickname.trimmingCharacters(in: .whitespaces))
        store.add(record)
        await store.refresh(record)
        isChecking = false
        dismiss()
    }
}
