import Foundation

struct CaseRecord: Codable, Identifiable, Equatable {
    let id: UUID
    var receiptNumber: String
    var nickname: String
    var lastStatus: CaseStatus?
    var lastChecked: Date?
    var errorMessage: String?

    init(id: UUID = UUID(), receiptNumber: String, nickname: String) {
        self.id = id
        self.receiptNumber = receiptNumber
        self.nickname = nickname
    }

    var displayName: String {
        nickname.isEmpty ? receiptNumber : nickname
    }
}
