import SwiftUI

struct CaseDetailView: View {
    let record: CaseRecord
    @EnvironmentObject var store: CaseStore

    private var current: CaseRecord {
        store.cases.first { $0.id == record.id } ?? record
    }

    var body: some View {
        List {
            Section("Receipt Number") {
                Text(current.receiptNumber)
                    .font(.system(.body, design: .monospaced))
            }

            if let status = current.lastStatus {
                Section("Status") {
                    Text(status.title)
                        .font(.headline)
                    if !status.description.isEmpty {
                        Text(status.description)
                            .font(.body)
                    }
                }
            }

            if let checked = current.lastChecked {
                Section("Last Checked") {
                    Text(checked.formatted(date: .long, time: .shortened))
                }
            }

            if let errorMsg = current.errorMessage {
                Section {
                    Text(errorMsg)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    store.delete(record)
                } label: {
                    Label("Remove Case", systemImage: "trash")
                }
            }
        }
        .navigationTitle(current.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await store.refresh(current) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}
