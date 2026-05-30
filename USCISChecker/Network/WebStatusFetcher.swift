import WebKit
import UIKit

@MainActor
class WebStatusFetcher: NSObject, StatusFetching {
    private let webView: WKWebView
    private var continuation: CheckedContinuation<CaseStatus, Error>?

    override init() {
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        super.init()
        webView.navigationDelegate = self
        webView.isHidden = true
    }

    func fetchStatus(receiptNumber: String) async throws -> CaseStatus {
        attachToWindowIfNeeded()
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let url = URL(string: "https://egov.uscis.gov/casestatus/mycasestatus.do")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = "appReceiptNum=\(receiptNumber)&initCaseSearch=CHECK+STATUS".data(using: .utf8)
            webView.load(request)
        }
    }

    private func attachToWindowIfNeeded() {
        guard webView.window == nil else { return }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first
        window?.addSubview(webView)
    }

    private func extractStatus() {
        let js = """
        (function() {
            if (document.title === "Just a moment...") return null;
            var h1s = Array.from(document.querySelectorAll('h1'));
            var statusH1 = h1s.find(function(h) {
                var t = h.innerText.trim();
                return t && t !== "Case Status Online";
            });
            if (!statusH1) return null;
            var container = statusH1.closest('div');
            var p = (container && container.querySelector('p')) || statusH1.nextElementSibling;
            return JSON.stringify({
                title: statusH1.innerText.trim(),
                description: (p && p.tagName === 'P') ? p.innerText.trim() : ''
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
