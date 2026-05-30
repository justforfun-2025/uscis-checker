import Foundation

enum ReceiptValidator {
    private static let validPrefixes: Set<String> = ["IOE", "MSC", "EAC", "WAC", "LIN", "SRC", "NBC"]

    static func isValid(_ number: String) -> Bool {
        guard number.count == 13 else { return false }
        let prefix = String(number.prefix(3))
        let digits = String(number.dropFirst(3))
        return validPrefixes.contains(prefix) && digits.allSatisfy(\.isNumber)
    }
}
