import WebKit
import UIKit

@MainActor
class WebStatusFetcher: NSObject, StatusFetching {
    private let webView: WKWebView
    private var continuation: CheckedContinuation<CaseStatus, Error>?
    private var receiptToSubmit: String?

    override init() {
        webView = WKWebView(frame: CGRect(x: -1000, y: -1000, width: 375, height: 812))
        super.init()
        webView.navigationDelegate = self
    }

    func fetchStatus(receiptNumber: String) async throws -> CaseStatus {
        attachToWindowIfNeeded()
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.receiptToSubmit = receiptNumber
            // Phase 1: load the search page (GET) so Cloudflare clears, then submit via JS
            webView.load(URLRequest(url: URL(string: "https://egov.uscis.gov/casestatus/mycasestatus.do")!))
        }
    }

    private func attachToWindowIfNeeded() {
        guard webView.window == nil else { return }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first?
            .addSubview(webView)
    }

    // Phase 1: search page is loaded — fill the form and submit
    private func submitForm() {
        let safeReceipt = receiptToSubmit ?? ""
        let js = """
        (function() {
            if (document.title === "Just a moment...") return "challenge";
            var input = document.querySelector('[name="appReceiptNum"]');
            if (!input) return "no-form";
            input.value = '\(safeReceipt)';
            var btn = document.querySelector('[type="submit"]');
            if (btn) { btn.click(); return "clicked"; }
            var form = input.closest('form');
            if (form) { form.submit(); return "submitted"; }
            return "no-submit";
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self else { return }
            let status = result as? String ?? "error"
            print("[WebStatusFetcher] submit: \(status)")
            switch status {
            case "challenge":
                break  // Cloudflare not resolved yet — wait for next didFinish
            case "no-form", "no-submit", "error":
                self.continuation?.resume(throwing: USCISError.invalidResponse)
                self.continuation = nil
                self.receiptToSubmit = nil
            default:
                self.receiptToSubmit = nil  // Form submitted — Phase 2: await results page
            }
        }
    }

    // Phase 2: results page loaded — extract the case status
    private func extractStatus() {
        let debugJS = "Array.from(document.querySelectorAll('h1,h2')).map(h => h.tagName+': '+h.innerText.trim()).join('\\n')"
        webView.evaluateJavaScript(debugJS) { result, _ in
            print("[WebStatusFetcher] Results headings:\n\(result ?? "none")")
        }

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
            else { return }  // Not the results page yet — wait for next didFinish

            self.continuation?.resume(returning: CaseStatus(title: extracted.title, description: extracted.description))
            self.continuation = nil
        }
    }
}

extension WebStatusFetcher: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if receiptToSubmit != nil {
            submitForm()
        } else if continuation != nil {
            extractStatus()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }

    private func handleNavigationFailure(_ error: Error) {
        let nsError = error as NSError
        // Cloudflare cancels the initial navigation to inject its challenge.
        // Ignore cancellation; another didFinish will fire when the real page loads.
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            print("[WebStatusFetcher] ignored cancellation (likely Cloudflare redirect)")
            return
        }
        continuation?.resume(throwing: error)
        continuation = nil
        receiptToSubmit = nil
    }
}

private struct ExtractedStatus: Decodable {
    let title: String
    let description: String
}
