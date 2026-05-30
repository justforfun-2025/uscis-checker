import WebKit

@MainActor
class WebStatusFetcher: NSObject, StatusFetching {
    private let webView: WKWebView
    private var continuation: CheckedContinuation<CaseStatus, Error>?

    override init() {
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
        super.init()
        webView.navigationDelegate = self
    }

    func fetchStatus(receiptNumber: String) async throws -> CaseStatus {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let url = URL(string: "https://egov.uscis.gov/casestatus/mycasestatus.do")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = "appReceiptNum=\(receiptNumber)&initCaseSearch=CHECK+STATUS".data(using: .utf8)
            webView.load(request)
        }
    }

    private func extractStatus() {
        let js = """
        (function() {
            if (document.title === "Just a moment...") return null;
            var h1 = document.querySelector('h1');
            if (!h1 || !h1.innerText.trim()) return null;
            var p = h1.closest('div')?.querySelector('p') || document.querySelector('p');
            return JSON.stringify({
                title: h1.innerText.trim(),
                description: p ? p.innerText.trim() : ''
            });
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self, self.continuation != nil else { return }
            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let extracted = try? JSONDecoder().decode(ExtractedStatus.self, from: data),
                  !extracted.title.isEmpty
            else { return }  // Still on challenge page — wait for next didFinish

            self.continuation?.resume(returning: CaseStatus(title: extracted.title, description: extracted.description))
            self.continuation = nil
        }
    }
}

extension WebStatusFetcher: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        extractStatus()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

private struct ExtractedStatus: Decodable {
    let title: String
    let description: String
}
