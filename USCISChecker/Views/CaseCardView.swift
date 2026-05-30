import SwiftUI

struct CaseCardView: View {
    let record: CaseRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.displayName)
                    .font(.headline)
                Spacer()
                if record.errorMessage != nil {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.red)
                }
            }
            if record.displayName != record.receiptNumber {
                Text(record.receiptNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let status = record.lastStatus {
                Text(status.title)
                    .font(.subheadline)
            } else {
                Text("Status unknown")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let checked = record.lastChecked {
                Text("Updated \(checked.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
