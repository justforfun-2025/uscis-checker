import Foundation

enum USCISError: Error {
    case invalidResponse
}

struct USCISClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchStatus(receiptNumber: String) async throws -> CaseStatus {
        var request = URLRequest(url: URL(string: "https://egov.uscis.gov/casestatus/mycasestatus.do")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.httpBody = "appReceiptNum=\(receiptNumber)&initCaseSearch=CHECK+STATUS".data(using: .utf8)

        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw USCISError.invalidResponse
        }
        return try parseHTML(html)
    }

    func parseHTML(_ html: String) throws -> CaseStatus {
        guard let h1Open = html.range(of: "<h1", options: .caseInsensitive),
              let h1Close = html.range(of: ">", range: h1Open.upperBound..<html.endIndex),
              let h1End = html.range(of: "</h1>", options: .caseInsensitive, range: h1Close.upperBound..<html.endIndex)
        else {
            throw USCISError.invalidResponse
        }

        let title = stripTags(String(html[h1Close.upperBound..<h1End.lowerBound]))
        guard !title.isEmpty else { throw USCISError.invalidResponse }

        let rest = String(html[h1End.upperBound...])
        guard let pOpen = rest.range(of: "<p", options: .caseInsensitive),
              let pClose = rest.range(of: ">", range: pOpen.upperBound..<rest.endIndex),
              let pEnd = rest.range(of: "</p>", options: .caseInsensitive, range: pClose.upperBound..<rest.endIndex)
        else {
            return CaseStatus(title: title, description: "")
        }

        let description = stripTags(String(rest[pClose.upperBound..<pEnd.lowerBound]))
        return CaseStatus(title: title, description: description)
    }

    private func stripTags(_ string: String) -> String {
        var result = ""
        var inTag = false
        for char in string {
            if char == "<" { inTag = true }
            else if char == ">" { inTag = false }
            else if !inTag { result.append(char) }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
